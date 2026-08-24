import Foundation
import KTPlatformContracts
import KTStackCore

// Nửa nginx của tunnel (write/activate/remove vhost, chọn port, recovery). Front nginx ở lại platform.
public final class TunnelOriginService: TunnelOriginConfiguring, @unchecked Sendable {
    enum PreparationError: LocalizedError {
        case siteUnavailable
        case originPortNotListening(Int)
        case nginxRecoveryFailed(Int, String)

        var errorDescription: String? {
            switch self {
            case .siteUnavailable:
                "The site is no longer available."
            case let .originPortNotListening(port):
                "Nginx did not start listening on tunnel origin port \(port). Restart local services and try sharing again."
            case let .nginxRecoveryFailed(port, message):
                "Nginx could not activate tunnel origin port \(port): \(message)"
            }
        }
    }

    private let paths: AppSupportPaths
    private let resolveSite: @MainActor (UUID) -> Site?
    private let generator: SiteConfigGenerator
    private let tunnelWriter = NginxTunnelVhostWriter()
    private let preflight = PortPreflight()
    private let nginx: NginxController

    public init(paths: AppSupportPaths, resolveSite: @escaping @MainActor (UUID) -> Site?) {
        self.paths = paths
        self.resolveSite = resolveSite
        generator = SiteConfigGenerator(paths: paths)
        nginx = NginxController(paths: paths, agents: LaunchAgentManager(paths: paths))
    }

    // Inverted check: port 80 free means nothing is serving, so the local stack is down.
    public nonisolated var isFrontListening: Bool {
        if case .available = preflight.check(port: 80) { return false }
        return true
    }

    @MainActor
    public func prepareOrigin(siteID: UUID) async throws -> Int {
        guard let site = resolveSite(siteID) else { throw PreparationError.siteUnavailable }
        let port = selectTunnelPort(siteID)
        try writeTunnelVhost(site: site, port: port, publicHost: nil, hostPrependFile: nil)
        try await activateTunnelVhost(port: port)
        return port
    }

    @MainActor
    public func applyPublicHost(_ host: String, siteID: UUID, port: Int, hostPrependFile: URL) async {
        guard let site = resolveSite(siteID) else { return }
        guard FileManager.default.fileExists(atPath: tunnelVhostURL(siteID).path) else { return }
        guard (try? writeTunnelVhost(site: site, port: port, publicHost: host, hostPrependFile: hostPrependFile)) != nil
        else { return }
        await reloadNginxTolerant()
    }

    public nonisolated func removeOrigin(siteID: UUID) {
        let url = tunnelVhostURL(siteID)
        guard FileManager.default.fileExists(atPath: url.path) else { return }
        try? FileManager.default.removeItem(at: url)
        reloadFrontTolerantDetached()
    }

    public nonisolated func removeAllOrigins(reloadFront: Bool) {
        guard let files = try? FileManager.default.contentsOfDirectory(
            at: paths.sitesEnabled,
            includingPropertiesForKeys: nil
        ) else { return }
        var removed = false
        for file in files where file.lastPathComponent.hasPrefix("tunnel-") && file.pathExtension == "conf" {
            try? FileManager.default.removeItem(at: file)
            removed = true
        }
        if removed, reloadFront { reloadFrontTolerantDetached() }
    }

    private func writeTunnelVhost(site: Site, port: Int, publicHost: String?, hostPrependFile: URL?) throws {
        let socket = site.type == .php ? paths.phpFpmSocket(generator.effectivePHPVersion(site.phpVersion)) : nil
        let config = tunnelWriter.vhost(
            site: site,
            port: port,
            phpFpmSocket: socket,
            accessLog: paths.siteAccessLog(site.domain),
            errorLog: paths.siteErrorLog(site.domain),
            publicHost: publicHost,
            supportsBodyRewrite: nginx.supportsResponseBodyRewrite(),
            hostPrependFile: hostPrependFile
        )
        try config.write(to: tunnelVhostURL(site.id), atomically: true, encoding: .utf8)
    }

    private func activateTunnelVhost(port: Int) async throws {
        if await reloadNginxTolerant(), await waitForTunnelPort(port) { return }
        try await restartNginxForTunnelPort(port, originalError: PreparationError.originPortNotListening(port))
    }

    @discardableResult
    private func reloadNginxTolerant() async -> Bool {
        for attempt in 0..<3 {
            do {
                try nginx.reload()
                return true
            } catch {
                if attempt == 2 { return false }
                try? await Task.sleep(nanoseconds: 150_000_000)
            }
        }
        return false
    }

    private func restartNginxForTunnelPort(_ port: Int, originalError: Error) async throws {
        do {
            try nginx.restart()
            if await waitForTunnelPort(port) { return }
            throw PreparationError.originPortNotListening(port)
        } catch {
            let message = [originalError.localizedDescription, error.localizedDescription]
                .filter { !$0.isEmpty }
                .joined(separator: " | ")
            throw PreparationError.nginxRecoveryFailed(port, message)
        }
    }

    private func waitForTunnelPort(_ port: Int) async -> Bool {
        for _ in 0..<20 {
            if HealthChecker.tcpConnect(host: "127.0.0.1", port: port, timeout: 0.3) { return true }
            try? await Task.sleep(nanoseconds: 100_000_000)
        }
        return false
    }

    private nonisolated func reloadFrontTolerantDetached() {
        Task { await self.reloadNginxTolerant() }
    }

    private func tunnelVhostURL(_ siteID: UUID) -> URL {
        paths.vhost("tunnel-\(siteID.uuidString)")
    }

    // Derive a stable base port from the site UUID so a restart reuses the same port; scan forward
    // (wrapping inside 41000-50999) to skip one already taken by another tunnel.
    func selectTunnelPort(_ siteID: UUID) -> Int {
        let base = stableBasePort(siteID)
        for offset in 0..<1000 {
            let port = 41000 + ((base - 41000 + offset) % 10000)
            if case .available = preflight.check(port: port) { return port }
        }
        return base
    }

    func stableBasePort(_ siteID: UUID) -> Int {
        41000 + siteID.uuidString.utf8.reduce(0) { ($0 &+ Int($1)) % 10000 }
    }
}

// Launchd mechanics cho cloudflared job; spec cố định keepAliveOnCrash:false, runAtLoad:true.
public struct TunnelJobRunner: TunnelJobManaging {
    private let launch: LaunchAgentManager

    public init(paths: AppSupportPaths) {
        launch = LaunchAgentManager(paths: paths)
    }

    public func bootstrapTunnelJob(label: String, binary: URL, arguments: [String], logPath: String) throws {
        let spec = LaunchAgentSpec(
            label: label,
            programArguments: [binary.path] + arguments,
            stdoutPath: logPath,
            stderrPath: logPath,
            keepAliveOnCrash: false,
            runAtLoad: true
        )
        try launch.bootstrap(spec)
    }

    public func bootoutTunnelJob(label: String) {
        try? launch.bootout(label)
    }

    public func isTunnelJobLoaded(label: String) -> Bool {
        launch.isLoadedNow(label)
    }

    public func bootoutAllTunnelJobs() {
        launch.bootout(matchingPrefix: "com.ktstack.tunnel.")
    }
}
