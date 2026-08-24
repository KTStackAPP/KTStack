import Combine
import Foundation
import KTPlatformContracts
import KTStackCore

@MainActor
public final class TunnelManager: ObservableObject {
    @Published public private(set) var sessions: [UUID: TunnelSession] = [:]

    public var ttl: TimeInterval = 30 * 60

    private let paths: AppSupportPaths
    private let origin: TunnelOriginService
    private let jobs: TunnelJobRunner
    private let provisioner: CloudflaredBinaryProvisioner
    private var activeSites: [UUID: Site] = [:]
    private var controllers: [UUID: TunnelController] = [:]
    private var startTasks: [UUID: Task<Void, Never>] = [:]
    private var ttlTasks: [UUID: Task<Void, Never>] = [:]

    public init(paths: AppSupportPaths = AppSupportPaths()) {
        self.paths = paths
        provisioner = CloudflaredBinaryProvisioner(paths: paths)
        jobs = TunnelJobRunner(paths: paths)
        // Site lookup từ bản ghi active của manager (phase M07-1); phase 2 chuyển sang App/registry.
        var lookup: (@MainActor (UUID) -> Site?)!
        origin = TunnelOriginService(paths: paths, resolveSite: { lookup($0) })
        lookup = { [weak self] in self?.activeSites[$0] }
    }

    public func isSharing(_ siteID: UUID) -> Bool {
        sessions[siteID]?.status.isBusy ?? false
    }

    public func session(_ siteID: UUID) -> TunnelSession? {
        sessions[siteID]
    }

    public func start(site: Site) {
        guard !isSharing(site.id), startTasks[site.id] == nil else { return }
        tearDown(site.id)
        activeSites[site.id] = site
        let startedAt = Date()
        sessions[site.id] = TunnelSession(
            siteID: site.id,
            domain: site.domain,
            secure: site.secure,
            status: .starting,
            startedAt: startedAt,
            expiresAt: ttl > 0 ? startedAt.addingTimeInterval(ttl) : nil
        )
        let target = TunnelSiteTarget(id: site.id, domain: site.domain, secure: site.secure)
        startTasks[target.id] = Task { [weak self] in
            await self?.runStart(target: target)
        }
        scheduleTTL(target.id)
    }

    public func stop(site siteID: UUID) {
        tearDown(siteID)
        sessions[siteID] = nil
    }

    public func reapStaleJobs() {
        jobs.bootoutAllTunnelJobs()
        origin.removeAllOrigins(reloadFront: true)
    }

    public func reconcile(sites: [Site]) {
        let live = Dictionary(sites.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
        for (siteID, session) in sessions {
            guard let site = live[siteID],
                  site.domain == session.domain, site.secure == session.secure
            else {
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
        let provisioner = provisioner
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
        origin.removeOrigin(siteID: siteID)
        activeSites[siteID] = nil
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

    private func runStart(target: TunnelSiteTarget) async {
        let siteID = target.id
        if Task.isCancelled { clearStart(siteID); return }
        guard origin.isFrontListening else {
            finishStart(siteID, status: .error("Local server isn't running — start KTStack's services first."))
            return
        }
        do {
            if Task.isCancelled { clearStart(siteID); return }
            let originPort = try await origin.prepareOrigin(siteID: siteID)
            if Task.isCancelled { clearStart(siteID); return }
            let binary = try await provisioner.ensureCloudflaredInstalled()
            if Task.isCancelled { clearStart(siteID); return }
            let controller = TunnelController(paths: paths, siteID: siteID)
            controllers[siteID] = controller
            await controller.start(
                binary: binary,
                originPort: originPort,
                localDomain: target.domain,
                onURL: { [weak self] url in
                    guard let host = url.host else { return }
                    await self?.applyPublicHost(target: target, port: originPort, publicHost: host)
                },
                onStatus: { [weak self] status in
                    Task { @MainActor [weak self] in
                        self?.updateStatus(siteID, status)
                    }
                }
            )
            startTasks[siteID] = nil
        } catch is CancellationError {
            clearStart(siteID)
        } catch {
            finishStart(siteID, status: .error(error.localizedDescription))
        }
    }

    private func applyPublicHost(target: TunnelSiteTarget, port: Int, publicHost: String) async {
        guard sessions[target.id]?.status.isBusy == true else { return }
        try? TunnelHostPrepend.write(
            to: paths.tunnelHostPrependFile,
            chainingPrepend: paths.dumpsPrependFile
        )
        await origin.applyPublicHost(
            publicHost,
            siteID: target.id,
            port: port,
            hostPrependFile: paths.tunnelHostPrependFile
        )
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
