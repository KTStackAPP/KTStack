import Foundation
import Combine

@MainActor
public final class TunnelManager: ObservableObject {
    @Published public private(set) var sessions: [UUID: TunnelSession] = [:]

    public var ttl: TimeInterval = 30 * 60

    private let paths: AppSupportPaths
    private let provisioner: CloudflaredBinaryProvisioner
    private let generator: SiteConfigGenerator
    private let tunnelWriter = NginxTunnelVhostWriter()
    private let preflight = PortPreflight()
    private let nginx: NginxController
    private var controllers: [UUID: TunnelController] = [:]
    private var startTasks: [UUID: Task<Void, Never>] = [:]
    private var ttlTasks: [UUID: Task<Void, Never>] = [:]

    public init(paths: AppSupportPaths = AppSupportPaths()) {
        self.paths = paths
        self.provisioner = CloudflaredBinaryProvisioner(paths: paths)
        self.generator = SiteConfigGenerator(paths: paths)
        self.nginx = NginxController(paths: paths, agents: LaunchAgentManager(paths: paths))
    }

    public func isSharing(_ siteID: UUID) -> Bool {
        sessions[siteID]?.status.isBusy ?? false
    }

    public func session(_ siteID: UUID) -> TunnelSession? { sessions[siteID] }

    public func start(site: Site) {
        guard !isSharing(site.id), startTasks[site.id] == nil else { return }
        tearDown(site.id)
        sessions[site.id] = TunnelSession(siteID: site.id, domain: site.domain,
                                          secure: site.secure, status: .starting)
        let siteID = site.id
        startTasks[siteID] = Task { [weak self] in
            await self?.runStart(site: site)
        }
        scheduleTTL(siteID)
    }

    public func stop(site siteID: UUID) {
        tearDown(siteID)
        sessions[siteID] = nil
    }

    public func reapStaleJobs() {
        LaunchAgentManager(paths: paths).bootout(matchingPrefix: "com.kdwarm.tunnel.")
        removeAllTunnelVhosts()
    }

    public func reconcile(sites: [Site]) {
        let live = Dictionary(sites.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
        for (siteID, session) in sessions {
            guard let site = live[siteID],
                  site.domain == session.domain, site.secure == session.secure else {
                stop(site: siteID)
                continue
            }
        }
    }

    public func shutdownAll() {
        for siteID in Set(controllers.keys).union(startTasks.keys).union(ttlTasks.keys) {
            tearDown(siteID)
        }
        sessions.removeAll()
        let provisioner = self.provisioner
        Task { await provisioner.cancel() }
    }

    private func tearDown(_ siteID: UUID) {
        startTasks[siteID]?.cancel()
        startTasks[siteID] = nil
        ttlTasks[siteID]?.cancel()
        ttlTasks[siteID] = nil
        if let controller = controllers.removeValue(forKey: siteID) {
            Task { await controller.stop() }
        }
        removeTunnelVhost(siteID)
    }

    private func scheduleTTL(_ siteID: UUID) {
        guard ttl > 0 else { return }
        let seconds = ttl
        ttlTasks[siteID] = Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
            if Task.isCancelled { return }
            self?.expire(siteID)
        }
    }

    private func expire(_ siteID: UUID) {
        guard isSharing(siteID) else { return }
        tearDown(siteID)
        updateStatus(siteID, .expired)
    }

    private func runStart(site: Site) async {
        let siteID = site.id
        if Task.isCancelled { clearStart(siteID); return }
        if case .available = preflight.check(port: 80) {
            finishStart(siteID, status: .error("Local server isn't running — start KDWarm's services first."))
            return
        }
        do {
            if Task.isCancelled { clearStart(siteID); return }
            let originPort = try prepareTunnelVhost(for: site)
            if Task.isCancelled { clearStart(siteID); return }
            let binary = try await provisioner.ensureInstalled { _ in }
            if Task.isCancelled { clearStart(siteID); return }
            let controller = TunnelController(paths: paths, siteID: siteID)
            controllers[siteID] = controller
            await controller.start(binary: binary, originPort: originPort, localDomain: site.domain) { [weak self] status in
                Task { @MainActor [weak self] in self?.updateStatus(siteID, status) }
            }
            startTasks[siteID] = nil
        } catch is CancellationError {
            clearStart(siteID)
        } catch {
            finishStart(siteID, status: .error(error.localizedDescription))
        }
    }

    private func updateStatus(_ siteID: UUID, _ status: TunnelStatus) {
        guard var session = sessions[siteID] else { return }
        session.status = status
        sessions[siteID] = session
    }

    private func finishStart(_ siteID: UUID, status: TunnelStatus) {
        updateStatus(siteID, status)
        startTasks[siteID] = nil
    }

    private func clearStart(_ siteID: UUID) {
        tearDown(siteID)
        sessions[siteID] = nil
    }

    private func prepareTunnelVhost(for site: Site) throws -> Int {
        let port = selectTunnelPort(site.id)
        let socket = site.type == .php ? paths.phpFpmSocket(generator.effectivePHPVersion(site.phpVersion)) : nil
        let config = tunnelWriter.vhost(site: site, port: port, phpFpmSocket: socket,
                                        accessLog: paths.siteAccessLog(site.domain),
                                        errorLog: paths.siteErrorLog(site.domain))
        try config.write(to: tunnelVhostURL(site.id), atomically: true, encoding: .utf8)
        try nginx.reload()
        return port
    }

    private func removeTunnelVhost(_ siteID: UUID) {
        let url = tunnelVhostURL(siteID)
        guard FileManager.default.fileExists(atPath: url.path) else { return }
        try? FileManager.default.removeItem(at: url)
        try? nginx.reload()
    }

    private func tunnelVhostURL(_ siteID: UUID) -> URL {
        paths.vhost("tunnel-\(siteID.uuidString)")
    }

    private func removeAllTunnelVhosts() {
        guard let files = try? FileManager.default.contentsOfDirectory(at: paths.sitesEnabled,
                                                                       includingPropertiesForKeys: nil) else { return }
        var removed = false
        for file in files where file.lastPathComponent.hasPrefix("tunnel-") && file.pathExtension == "conf" {
            try? FileManager.default.removeItem(at: file)
            removed = true
        }
        if removed { try? nginx.reload() }
    }

    private func selectTunnelPort(_ siteID: UUID) -> Int {
        let base = 41_000 + stablePortOffset(siteID)
        for offset in 0..<1_000 {
            let port = 41_000 + ((base - 41_000 + offset) % 10_000)
            if case .available = preflight.check(port: port) { return port }
        }
        return base
    }

    private func stablePortOffset(_ siteID: UUID) -> Int {
        siteID.uuidString.utf8.reduce(0) { ($0 &+ Int($1)) % 10_000 }
    }
}
