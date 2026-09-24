import Foundation
import KTStackCore

extension KTIPCCommandDispatcher {
    static let backupUnavailable =
        "Database backup is not available from the CLI or MCP yet. Use KTStack › Database › Backups."

    func handleServicesList(id: String?) async -> KTIPCResponse {
        guard let services = await servicesProvider() else {
            return .fail("Service manager unavailable", id: id)
        }
        let list: [KTIPCServiceInfo] = await MainActor.run {
            services.snapshots.map { snap in
                KTIPCServiceInfo(name: snap.kind.rawValue, running: snap.status == .running, detail: snap.detail)
            }
        }
        guard let data = try? JSONEncoder().encode(list), let str = String(data: data, encoding: .utf8) else {
            return .fail("Failed to encode services", id: id)
        }
        return .ok(str, id: id)
    }

    func handleServiceAction(request: KTIPCRequest) async -> KTIPCResponse {
        guard let name = request.params?["service"], let kind = ServiceKind(rawValue: name) else {
            let valid = ServiceKind.allCases.map(\.rawValue).joined(separator: ", ")
            return .fail("Missing or invalid service name. Valid: \(valid)", id: request.id)
        }
        guard let services = await servicesProvider() else {
            return .fail("Service manager unavailable", id: request.id)
        }
        let message: String = await MainActor.run {
            let running = services.snapshot(kind)?.status == .running
            switch request.method {
            case "services.start":
                guard !running else { return "\(name) is already running" }
                services.toggle(kind)
                return "Starting \(name)"
            case "services.stop":
                guard running else { return "\(name) is already stopped" }
                services.toggle(kind)
                return "Stopping \(name)"
            default:
                services.restart(kind)
                return "Restarting \(name)"
            }
        }
        return .ok(message, id: request.id)
    }
}
