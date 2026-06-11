import Foundation

/// Starts/stops/reloads nginx, supervised by `ManagedProcess`.
///
/// nginx always launches with `-p <app-support>` so its compiled prefix is overridden and
/// it runs from the writable tree (creating its own temp dirs there). `daemon off;` keeps
/// the master in the foreground under supervision. Configs are written by `NginxConfigWriter`
/// and always `listen 0.0.0.0:<port>` (never a loopback interface — that needs root).
public final class NginxController: @unchecked Sendable {
    private let paths: AppSupportPaths
    private let lock = NSLock()
    private var managed: ManagedProcess?

    public var onExit: (@Sendable (ManagedProcess.State) -> Void)?

    public init(paths: AppSupportPaths) {
        self.paths = paths
    }

    public var isRunning: Bool {
        lock.lock(); defer { lock.unlock() }
        return managed?.isRunning ?? false
    }

    /// Launch the foreground master. Configs must already be written by the orchestrator.
    public func start() throws {
        lock.lock()
        guard managed == nil else { lock.unlock(); return }
        lock.unlock()

        let proc = ManagedProcess(
            label: "nginx",
            executable: paths.nginxBinary,
            arguments: ["-p", paths.root.path, "-c", paths.nginxConf.path, "-g", "daemon off;"],
            workingDirectory: paths.root,
            logFile: paths.nginxErrorLog)
        proc.onTerminate = { [weak self] state in
            self?.lock.lock(); self?.managed = nil; self?.lock.unlock()
            self?.onExit?(state)
        }
        try proc.start()

        lock.lock(); managed = proc; lock.unlock()
    }

    /// Hot-reload the config (`nginx -s reload`) without dropping the listening socket.
    public func reload() throws {
        try runControlCommand(["-s", "reload"])
    }

    /// Stop the master. SIGTERM is nginx's *fast* shutdown signal, so signalling the master
    /// directly (via `ManagedProcess.stop`) is both correct and quicker than spawning a
    /// separate `nginx -s quit` round-trip — important on the app-quit path where this runs
    /// synchronously. `grace` bounds the SIGTERM→SIGKILL window.
    public func stop(grace: TimeInterval = 3.0) {
        lock.lock(); let p = managed; managed = nil; lock.unlock()
        p?.stop(gracePeriod: grace)
    }

    /// One-shot `nginx -p <prefix> -c <conf> <args>` (e.g. `-s reload` / `-s quit`).
    private func runControlCommand(_ extra: [String]) throws {
        let proc = Process()
        proc.executableURL = paths.nginxBinary
        proc.arguments = ["-p", paths.root.path, "-c", paths.nginxConf.path] + extra
        proc.standardOutput = FileHandle.nullDevice
        proc.standardError = FileHandle.nullDevice
        try proc.run()
        proc.waitUntilExit()
    }
}
