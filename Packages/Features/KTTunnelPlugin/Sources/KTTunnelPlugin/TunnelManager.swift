import Combine
import Foundation
import KTPlatformContracts
import KTStackCore

@MainActor
public final class TunnelManager: ObservableObject {
    @Published public private(set) var sessions: [UUID: TunnelSession] = [:]

    public var ttl: TimeInterval = 30 * 60

    private let paths: AppSupportPaths
    private let origin: any TunnelOriginConfiguring
    private let jobs: any TunnelJobManaging
    private let binaries: any TunnelBinaryProviding
    private var controllers: [UUID: TunnelController] = [:]
    private var startTasks: [UUID: Task<Void, Never>] = [:]
    private var ttlTasks: [UUID: Task<Void, Never>] = [:]
    private var tokens: [UUID: UUID] = [:]

    public init(
        origin: any TunnelOriginConfiguring,
        jobs: any TunnelJobManaging,
        binaries: any TunnelBinaryProviding,
        paths: AppSupportPaths = AppSupportPaths()
    ) {
        self.origin = origin
        self.jobs = jobs
        self.binaries = binaries
        self.paths = paths
    }

    public func isSharing(_ siteID: UUID) -> Bool {
        sessions[siteID]?.status.isBusy ?? false
    }

    public func session(_ siteID: UUID) -> TunnelSession? {
        sessions[siteID]
    }

    public func start(target: TunnelSiteTarget) {
        guard !isSharing(target.id), startTasks[target.id] == nil else { return }
        tearDown(target.id)
        let token = UUID()
        tokens[target.id] = token
        let startedAt = Date()
        sessions[target.id] = TunnelSession(
            siteID: target.id,
            domain: target.domain,
            secure: target.secure,
            status: .starting,
            startedAt: startedAt,
            expiresAt: ttl > 0 ? startedAt.addingTimeInterval(ttl) : nil
        )
        startTasks[target.id] = Task { [weak self] in
            await self?.runStart(target: target, token: token)
        }
        scheduleTTL(target.id)
    }

    public func stop(site siteID: UUID) {
        tearDown(siteID)
        tokens[siteID] = nil
        sessions[siteID] = nil
    }

    public func reconcile(targets: [TunnelSiteTarget]) {
        let live = Dictionary(targets.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
        for (siteID, session) in sessions {
            guard let target = live[siteID],
                  target.domain == session.domain, target.secure == session.secure
            else {
                stop(site: siteID)
                continue
            }
        }
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

    private func runStart(target: TunnelSiteTarget, token: UUID) async {
        let siteID = target.id
        if Task.isCancelled { clearStart(siteID, token); return }
        guard origin.isFrontListening else {
            finishStart(siteID, token, status: .error("Local server isn't running — start KTStack's services first."))
            return
        }
        do {
            if Task.isCancelled { clearStart(siteID, token); return }
            let originPort = try await origin.prepareOrigin(siteID: siteID)
            if Task.isCancelled { clearStart(siteID, token); return }
            let binary = try await binaries.ensureCloudflaredInstalled()
            if Task.isCancelled || tokens[siteID] != token { clearStart(siteID, token); return }
            let controller = TunnelController(paths: paths, jobs: jobs, siteID: siteID)
            controllers[siteID] = controller
            await controller.start(
                binary: binary,
                originPort: originPort,
                localDomain: target.domain,
                watchdog: binaries.watchdogExecutable.map {
                    TunnelWatchdogLaunch(executable: $0, deadline: sessions[siteID]?.expiresAt?.addingTimeInterval(60))
                },
                onURL: { [weak self] url in
                    guard let host = url.host else { return }
                    await self?.applyPublicHost(target: target, port: originPort, publicHost: host, token: token)
                },
                onStatus: { [weak self] status in
                    Task { @MainActor [weak self] in
                        self?.updateStatus(siteID, status, token: token)
                    }
                }
            )
            if tokens[siteID] == token { startTasks[siteID] = nil }
        } catch is CancellationError {
            clearStart(siteID, token)
        } catch {
            finishStart(siteID, token, status: .error(error.localizedDescription))
        }
    }

    private func applyPublicHost(target: TunnelSiteTarget, port: Int, publicHost: String, token: UUID) async {
        guard tokens[target.id] == token, sessions[target.id]?.status.isBusy == true else { return }
        // Prepend file feature-owned (WordPress/PHP semantics); platform chỉ nhận path để tham chiếu.
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

    private func updateStatus(_ siteID: UUID, _ status: TunnelStatus, token: UUID? = nil) {
        if let token, tokens[siteID] != token { return }
        guard var session = sessions[siteID] else { return }
        session.status = status
        sessions[siteID] = session
    }

    private func finishStart(_ siteID: UUID, _ token: UUID, status: TunnelStatus) {
        guard tokens[siteID] == token else { return }
        updateStatus(siteID, status)
        startTasks[siteID] = nil
    }

    private func clearStart(_ siteID: UUID, _ token: UUID) {
        guard tokens[siteID] == token else { return }
        tearDown(siteID)
        tokens[siteID] = nil
        sessions[siteID] = nil
    }
}
