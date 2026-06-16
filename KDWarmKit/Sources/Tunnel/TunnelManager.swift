import Foundation
import Combine

@MainActor
public final class TunnelManager: ObservableObject {
    @Published public private(set) var sessions: [UUID: TunnelSession] = [:]

    public var ttl: TimeInterval = 30 * 60

    private let paths: AppSupportPaths
    private let provisioner: CloudflaredBinaryProvisioner
    private let preflight = PortPreflight()
    private var controllers: [UUID: TunnelController] = [:]
    private var startTasks: [UUID: Task<Void, Never>] = [:]
    private var ttlTasks: [UUID: Task<Void, Never>] = [:]

    public init(paths: AppSupportPaths = AppSupportPaths()) {
        self.paths = paths
        self.provisioner = CloudflaredBinaryProvisioner(paths: paths)
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
        let siteID = site.id, domain = site.domain, secure = site.secure
        startTasks[siteID] = Task { [weak self] in
            await self?.runStart(siteID: siteID, domain: domain, secure: secure)
        }
        scheduleTTL(siteID)
    }

    public func stop(site siteID: UUID) {
        tearDown(siteID)
        sessions[siteID] = nil
    }

    public func reapStaleJobs() {
        LaunchAgentManager(paths: paths).bootout(matchingPrefix: "com.kdwarm.tunnel.")
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

    private func runStart(siteID: UUID, domain: String, secure: Bool) async {
        if Task.isCancelled { clearStart(siteID); return }
        if case .available = preflight.check(port: 80) {
            finishStart(siteID, status: .error("Local server isn't running — start KDWarm's services first."))
            return
        }
        do {
            if Task.isCancelled { clearStart(siteID); return }
            let binary = try await provisioner.ensureInstalled { _ in }
            if Task.isCancelled { clearStart(siteID); return }
            let controller = TunnelController(paths: paths, siteID: siteID)
            controllers[siteID] = controller
            await controller.start(binary: binary, domain: domain, secure: secure) { [weak self] status in
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
}
