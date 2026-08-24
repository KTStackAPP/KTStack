import KTPlatformContracts
import KTPluginKit
import KTStackCore

// Headless plugin: conform PluginLifecycle, KHÔNG KTStackPlugin (không descriptor/sidebar).
// App inject `manager` vào Sites screen qua environmentObject.
public final class KTTunnelPlugin: PluginLifecycle {
    private let origin: any TunnelOriginConfiguring
    private let jobs: any TunnelJobManaging
    private let binaries: any TunnelBinaryProviding
    private let paths: AppSupportPaths

    @MainActor public lazy var manager = TunnelManager(
        origin: origin,
        jobs: jobs,
        binaries: binaries,
        paths: paths
    )

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

    // Reap crash-leftover jobs + vhosts; App gọi tường minh (sync) trước services.startAll để
    // stale tunnel vhost không làm nginx -t fail và sập front.
    public nonisolated func reapStaleJobs() {
        jobs.bootoutAllTunnelJobs()
        origin.removeAllOrigins(reloadFront: true)
    }

    public func start() async {}

    // Quit cleanup: chỉ file/process ops (nonisolated) vì applicationWillTerminate block main thread.
    // KHÔNG reload nginx (server sắp bootout), KHÔNG đụng manager (@MainActor) → tránh deadlock.
    public func shutdown() async {
        jobs.bootoutAllTunnelJobs()
        origin.removeAllOrigins(reloadFront: false)
    }
}
