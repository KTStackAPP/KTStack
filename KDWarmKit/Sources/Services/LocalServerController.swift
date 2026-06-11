import Foundation
import Combine

/// Orchestrates the Phase 2 HTTP slice: stage binaries → ensure the directory tree → write
/// configs → pre-flight the port → boot php-fpm then nginx. The UI (menu bar + Sites view)
/// observes this object; all published state mutates on the main actor.
///
/// Boot order is php-fpm BEFORE nginx (nginx's fastcgi_pass needs a live socket); shutdown is
/// the reverse. In this phase the children are dev-shim processes killed on app quit; Phase 6
/// promotes them to persistent launchd services.
@MainActor
public final class LocalServerController: ObservableObject {
    @Published public private(set) var nginxStatus: ServiceStatus = .stopped
    @Published public private(set) var phpStatus: ServiceStatus = .stopped
    @Published public private(set) var isBusy = false
    @Published public private(set) var lastError: String?

    public let demoDomain = "demo.test"
    public let poolName = "demo"
    public let httpPort = 80

    /// `~/Sites/WWW/demo/public` — the single hardcoded site this phase serves.
    public let siteRoot: URL

    private let paths: AppSupportPaths
    private let bundleBinDir: URL
    private let nginx: NginxController
    private let php: PHPFPMController
    private let stager: BinaryStager
    private let nginxWriter = NginxConfigWriter()
    private let preflight = PortPreflight()

    /// - Parameter bundleBinDir: `KDWarm.app/Contents/Resources/bin` (the vendored binaries).
    public init(bundleBinDir: URL,
                paths: AppSupportPaths = AppSupportPaths()) {
        self.paths = paths
        self.bundleBinDir = bundleBinDir
        self.nginx = NginxController(paths: paths)
        self.php = PHPFPMController(paths: paths, poolName: poolName)
        self.stager = BinaryStager(bundleBinDir: bundleBinDir, paths: paths)
        self.siteRoot = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Sites/WWW/demo/public", isDirectory: true)

        // An unexpected child exit drops the whole slice back to a consistent stopped state.
        nginx.onExit = { [weak self] state in
            Task { @MainActor in self?.handleUnexpectedExit("Nginx", state) }
        }
        php.onExit = { [weak self] state in
            Task { @MainActor in self?.handleUnexpectedExit("PHP-FPM", state) }
        }
    }

    public var isRunning: Bool { nginxStatus == .running && phpStatus == .running }

    public func toggle() { isRunning ? stop() : start() }

    public func start() {
        guard !isBusy, !isRunning else { return }
        isBusy = true; lastError = nil
        nginxStatus = .starting; phpStatus = .starting

        let paths = self.paths
        let stager = self.stager
        let writer = self.nginxWriter
        let preflight = self.preflight
        let php = self.php
        let nginx = self.nginx
        let domain = demoDomain, pool = poolName, root = siteRoot, port = httpPort

        Task.detached(priority: .userInitiated) {
            do {
                try stager.stageIfNeeded()
                try Self.provisionSampleSite(at: root, domain: domain)
                try PHPFPMPoolWriter().writeDemo(paths: paths, poolName: pool)
                try writer.writeDemo(paths: paths, domain: domain, siteRoot: root, poolName: pool, port: port)

                switch preflight.check(port: port) {
                case .available: break
                case .inUse(_, let message), .blocked(let message):
                    await self.finishStart(error: message); return
                }

                try php.start()
                try await Self.waitForSocket(paths.phpFpmSocket(pool))
                try nginx.start()
                await self.finishStart(error: nil)
            } catch {
                php.stop(); nginx.stop()
                await self.finishStart(error: error.localizedDescription)
            }
        }
    }

    public func stop() {
        guard !isBusy else { return }
        isBusy = true
        let php = self.php, nginx = self.nginx
        Task.detached(priority: .userInitiated) {
            nginx.stop()
            php.stop()
            await MainActor.run {
                self.nginxStatus = .stopped
                self.phpStatus = .stopped
                self.isBusy = false
            }
        }
    }

    /// Synchronous teardown for app termination — guarantees no orphaned children remain.
    /// Runs on the main thread during `applicationWillTerminate`, so it uses a SHORT grace:
    /// SIGTERM makes nginx/php-fpm masters exit in well under a second; the brief cap avoids
    /// a beach-balled quit if a master is wedged.
    public func shutdownForQuit() {
        nginx.stop(grace: 0.5)
        php.stop(grace: 0.5)
    }

    // MARK: - Private

    private func finishStart(error: String?) {
        isBusy = false
        if let error {
            lastError = error
            nginxStatus = nginx.isRunning ? .running : .error
            phpStatus = php.isRunning ? .running : .error
        } else {
            nginxStatus = nginx.isRunning ? .running : .error
            phpStatus = php.isRunning ? .running : .error
        }
    }

    private func handleUnexpectedExit(_ who: String, _ state: ManagedProcess.State) {
        // Always reconcile published status with reality so a dead process never shows as
        // running. Only the error MESSAGE is suppressed during a start/stop transition,
        // where exits are self-inflicted (otherwise a real crash in a busy window is lost).
        if !isBusy, case .failed(let reason) = state {
            lastError = "\(who) exited unexpectedly: \(reason)"
        }
        nginxStatus = nginx.isRunning ? .running : .stopped
        phpStatus = php.isRunning ? .running : .stopped
    }

    /// Poll for the php-fpm socket so nginx never starts before FastCGI is accepting.
    private nonisolated static func waitForSocket(_ url: URL, timeout: TimeInterval = 5) async throws {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if FileManager.default.fileExists(atPath: url.path) { return }
            try await Task.sleep(nanoseconds: 50_000_000)
        }
        throw NSError(domain: "KDWarm", code: 1,
                      userInfo: [NSLocalizedDescriptionKey: "php-fpm socket did not appear in time."])
    }

    /// Create `~/Sites/WWW/demo/public/index.php` (phpinfo) on first start if absent.
    private nonisolated static func provisionSampleSite(at root: URL, domain: String) throws {
        let fm = FileManager.default
        try fm.createDirectory(at: root, withIntermediateDirectories: true)
        let index = root.appendingPathComponent("index.php")
        guard !fm.fileExists(atPath: index.path) else { return }
        let body = """
        <?php
        // KDWarm demo site — served at http://\(domain) (Phase 2 HTTP slice).
        echo "<h1>KDWarm · \(domain) is live</h1>";
        phpinfo();
        """
        try body.write(to: index, atomically: true, encoding: .utf8)
    }
}
