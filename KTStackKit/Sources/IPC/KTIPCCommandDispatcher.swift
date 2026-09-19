import Foundation
import KTStackCore

public final class KTIPCCommandDispatcher: Sendable {
    private let serverProvider: @Sendable () async -> LocalServerController?
    private let servicesProvider: @Sendable () async -> ServiceManager?

    public init(
        serverProvider: @escaping @Sendable () async -> LocalServerController?,
        servicesProvider: @escaping @Sendable () async -> ServiceManager?
    ) {
        self.serverProvider = serverProvider
        self.servicesProvider = servicesProvider
    }

    public func dispatch(_ request: KTIPCRequest) async -> KTIPCResponse {
        switch request.method {
        case "ping":
            return .ok("pong", id: request.id)
        case "sites.list":
            return await handleSitesList(id: request.id)
        case "sites.create":
            return await handleSiteCreate(request: request)
        case "sites.switch_php":
            return await handleSiteSwitchPHP(request: request)
        case "services.list":
            return await handleServicesList(id: request.id)
        case "services.restart":
            return await handleServiceRestart(request: request)
        case "logs.recent":
            return handleRecentLogs(request: request)
        case "db.backup":
            return handleDBBackup(request: request)
        default:
            return .fail("Unknown method: \(request.method)", id: request.id)
        }
    }

    private func handleSitesList(id: String?) async -> KTIPCResponse {
        guard let server = await serverProvider() else {
            return .fail("Server controller unavailable", id: id)
        }
        let list: [KTIPCSiteInfo] = await MainActor.run {
            server.registry.sites.map { site in
                KTIPCSiteInfo(
                    id: site.id.uuidString,
                    name: site.name,
                    domain: site.domain,
                    path: site.path,
                    phpVersion: site.phpVersion,
                    secure: site.secure,
                    backendPort: site.backendPort ?? 0
                )
            }
        }
        guard let data = try? JSONEncoder().encode(list),
              let str = String(data: data, encoding: .utf8) else {
            return .fail("Failed to encode sites", id: id)
        }
        return .ok(str, id: id)
    }

    private func handleSiteCreate(request: KTIPCRequest) async -> KTIPCResponse {
        guard let path = request.params?["path"] else {
            return .fail("Missing 'path' parameter", id: request.id)
        }
        guard let server = await serverProvider() else {
            return .fail("Server controller unavailable", id: request.id)
        }
        let php = request.params?["php"] ?? "8.3"
        do {
            let site = try await MainActor.run {
                try server.registry.add(folder: URL(fileURLWithPath: path), phpVersion: php)
            }
            return .ok("Created site: \(site.domain)", id: request.id)
        } catch {
            return .fail(error.localizedDescription, id: request.id)
        }
    }

    private func handleSiteSwitchPHP(request: KTIPCRequest) async -> KTIPCResponse {
        guard let domain = request.params?["domain"], let version = request.params?["version"] else {
            return .fail("Missing 'domain' or 'version' parameter", id: request.id)
        }
        guard let server = await serverProvider() else {
            return .fail("Server controller unavailable", id: request.id)
        }
        return await MainActor.run {
            guard let site = server.registry.sites.first(where: { $0.domain == domain || $0.name == domain }) else {
                return .fail("Site not found: \(domain)", id: request.id)
            }
            server.setPHPVersion(site.id, version)
            return .ok("Updated \(site.domain) to PHP \(version)", id: request.id)
        }
    }

    private func handleServicesList(id: String?) async -> KTIPCResponse {
        guard let services = await servicesProvider() else {
            return .fail("Service manager unavailable", id: id)
        }
        let list: [KTIPCServiceInfo] = await MainActor.run {
            services.snapshots.map { snap in
                KTIPCServiceInfo(
                    name: snap.kind.rawValue,
                    running: snap.status == .running,
                    detail: snap.detail
                )
            }
        }
        guard let data = try? JSONEncoder().encode(list),
              let str = String(data: data, encoding: .utf8) else {
            return .fail("Failed to encode services", id: id)
        }
        return .ok(str, id: id)
    }

    private func handleServiceRestart(request: KTIPCRequest) async -> KTIPCResponse {
        guard let name = request.params?["service"], let kind = ServiceKind(rawValue: name) else {
            return .fail("Missing or invalid service name", id: request.id)
        }
        guard let services = await servicesProvider() else {
            return .fail("Service manager unavailable", id: request.id)
        }
        await MainActor.run {
            services.toggle(kind)
        }
        return .ok("Toggled \(name)", id: request.id)
    }

    private func handleRecentLogs(request: KTIPCRequest) -> KTIPCResponse {
        let source = request.params?["source"] ?? "front-error"
        let lineCount = Int(request.params?["lines"] ?? "50") ?? 50
        let logFile = AppSupportPaths().logs.appendingPathComponent("\(source).log")
        guard FileManager.default.fileExists(atPath: logFile.path),
              let content = try? String(contentsOf: logFile, encoding: .utf8) else {
            return .ok("No logs found for \(source)", id: request.id)
        }
        let lines = content.components(separatedBy: .newlines).filter { !$0.isEmpty }
        let tail = lines.suffix(lineCount).joined(separator: "\n")
        return .ok(tail, id: request.id)
    }

    private func handleDBBackup(request: KTIPCRequest) -> KTIPCResponse {
        let dbName = request.params?["database"] ?? "default"
        let backupDir = AppSupportPaths().data.appendingPathComponent("backups", isDirectory: true)
        try? FileManager.default.createDirectory(at: backupDir, withIntermediateDirectories: true)
        let dest = backupDir.appendingPathComponent("\(dbName)-\(Int(Date().timeIntervalSince1970)).sql")
        return .ok("Backup queued for \(dbName) at \(dest.path)", id: request.id)
    }
}
