import Combine
import Foundation
import KTStackCore

/// The outcome of a `validateNginxConfig()` call.
/// - `valid`: nginx -t exited 0 — config is OK.
/// - `invalid(String)`: nginx -t exited non-zero — stderr describes the problem.
/// - `couldNotRun`: the nginx binary is absent or not executable; result is indeterminate.
public enum NginxValidationResult: Sendable, Equatable {
    case valid
    case invalid(String)
    case couldNotRun
}

@MainActor
public final class LocalServerController: ObservableObject {
    @Published public internal(set) var nginxStatus: ServiceStatus = .stopped
    @Published public internal(set) var phpStatus: ServiceStatus = .stopped
    @Published public internal(set) var isBusy = false
    @Published public internal(set) var lastError: String?
    @Published public internal(set) var apacheInstalled = false
    @Published public internal(set) var apacheInstalling = false
    @Published public internal(set) var apacheInstallError: String?
    // Non-nil while the server start is downloading the default PHP runtime on a fresh install.
    @Published public internal(set) var bootstrapStatus: String?

    public let httpPort = 80
    public let registry: SiteRegistry
    public var onSitesChanged: (([Site]) -> Void)?

    nonisolated let tld: String

    nonisolated let paths: AppSupportPaths
    nonisolated let agents: LaunchAgentManager
    nonisolated let nginx: NginxController
    nonisolated let backends: SiteBackendSupervisor
    nonisolated let pools: PHPFPMPoolManager
    nonisolated let upstreamProbe: UpstreamProbe
    nonisolated let generator: SiteConfigGenerator
    nonisolated let stager: BinaryStager
    nonisolated let preflight = PortPreflight()
    nonisolated let watcher = RegisteredSiteWatcher()
    nonisolated let mkcert: MkcertRunner
    nonisolated let certMinter: CertMinter
    nonisolated let httpsProvisioner: SiteHTTPSProvisioner
    var didSeed = false
    var pendingReconcile = false

    public init(
        bundleBinDir: URL,
        paths: AppSupportPaths = AppSupportPaths(),
        tld: String = AppPreferences.defaultTLD,
        adoptRunningStack: Bool = false
    ) {
        self.paths = paths
        self.tld = tld
        agents = LaunchAgentManager(paths: paths)
        registry = SiteRegistry(
            storeURL: paths.sitesRegistryFile,
            tld: tld,
            installedPHP: { BundledPHP.availableVersions(php: paths.phpRuntimesRoot) }
        )
        nginx = NginxController(paths: paths, agents: agents)
        backends = SiteBackendSupervisor(paths: paths, agents: agents)
        pools = PHPFPMPoolManager(paths: paths, agents: agents)
        upstreamProbe = UpstreamProbe()
        generator = SiteConfigGenerator(paths: paths)
        stager = BinaryStager(bundleBinDir: bundleBinDir, paths: paths)
        mkcert = MkcertRunner(mkcert: paths.mkcertBinary, caroot: paths.caDir)
        certMinter = CertMinter(paths: paths, runner: MkcertRunner(mkcert: paths.mkcertBinary, caroot: paths.caDir))
        httpsProvisioner = SiteHTTPSProvisioner(
            paths: paths,
            tld: tld,
            mkcert: mkcert,
            certMinter: certMinter
        )

        registry.onChange = { [weak self] in self?.onRegistryChanged() }
        watcher.onChange = { [weak self] folder in
            Task { @MainActor in self?.handleFolderChange(folder) }
        }

        // Pre-upgrade PHP sites decode with no backendPort; assign one before the front renders.
        registry.assignBackendPortsIfNeeded()
        apacheInstalled = paths.apacheAvailable()

        // Chỉ app thật adopt stack đang chạy: instance test (registry rỗng) mà reattach sẽ bootout
        // backend thật qua launchd. isRunningNow vì cache lạnh luôn trả false lúc init.
        if adoptRunningStack, nginx.isRunningNow { reattachOnLaunch() } else { recomputeStatus() }
    }

    public func refreshStatus() {
        guard !isBusy else { return }
        recomputeStatus()
    }

    private func reattachOnLaunch() {
        let required = generator.poolVersions(for: registry.sites)
        _ = try? pools.reconcile(required: required)
        recomputeStatus()
        refreshWatches()
        // Front is already up; bring each site's backend up too. Take the busy lock so a user
        // start/stop can't race this on the same com.ktstack.site.* labels.
        guard !isBusy else { return }
        isBusy = true
        let sites = registry.sites
        Task.detached(priority: .userInitiated) { [backends, self] in
            await backends.reconcile(sites: sites)
            await MainActor.run { self.isBusy = false }
        }
    }

    public var isRunning: Bool {
        nginxStatus == .running
    }

    public var availableVersions: [String] {
        let v = BundledPHP.availableVersions(php: paths.phpRuntimesRoot)
        return v.isEmpty ? [BundledPHP.defaultVersion] : v
    }

    public var phpRunning: Bool {
        let active = pools.activeVersions
        return !active.isEmpty && active.allSatisfy { pools.isRunning(version: $0) }
    }

    func finish(missing: [String], error: String?) {
        isBusy = false
        if let error { lastError = error }
        else if !missing.isEmpty {
            let pins = missing.joined(separator: ", ")
            let installed = BundledPHP.availableVersions(php: paths.phpRuntimesRoot)
            if let fallback = installed.max(by: { $0.compare($1, options: .numeric) == .orderedAscending }) {
                lastError = "PHP \(pins) not installed — those sites are running on PHP \(fallback) for now. "
                    + "Install \(pins) from Runtimes to use the pinned version."
            } else {
                lastError = "PHP \(pins) not installed and no PHP is available — those sites won't serve. "
                    + "Install PHP from Runtimes."
            }
        }
        recomputeStatus()
        refreshWatches()
        certMinter.pruneOrphans(keeping: Set(registry.sites.map(\.domain))) // drop removed sites' leaves
        if pendingReconcile { pendingReconcile = false; reconcile() }
    }

    func recomputeStatus() {
        let nginxRunning = nginx.isRunning
        let newNginx: ServiceStatus = nginxRunning ? .running : .stopped
        let active = pools.activeVersions
        let allUp = !active.isEmpty && active.allSatisfy { pools.isRunning(version: $0) }
        let newPhp: ServiceStatus = allUp ? .running : .stopped
        if newNginx != nginxStatus { nginxStatus = newNginx }
        if newPhp != phpStatus { phpStatus = newPhp }
    }
}
