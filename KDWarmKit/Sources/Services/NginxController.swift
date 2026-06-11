import Foundation

/// Starts/stops/reloads nginx as a user LaunchAgent that PERSISTS across app quit (the app is a
/// controller, not the process parent). nginx launches with `-p <app-support>` so its compiled
/// prefix is overridden and it runs from the writable tree; `daemon off;` keeps the master in the
/// foreground under launchd. Configs are written by `NginxConfigWriter` and always
/// `listen 0.0.0.0:<port>` (never a loopback interface — that needs root). launchd `KeepAlive`
/// auto-restarts a crash; a clean stop is a `bootout`.
public final class NginxController: @unchecked Sendable {
    private let paths: AppSupportPaths
    private let agents: LaunchAgentManager
    private let label = ServiceKind.nginx.launchdLabel

    public init(paths: AppSupportPaths, agents: LaunchAgentManager) {
        self.paths = paths
        self.agents = agents
    }

    /// Loaded into launchd? (Reattaches to a job left running by a previous app session.)
    public var isRunning: Bool { agents.isLoaded(label) }

    /// Bootstrap the launchd job. Configs must already be written by the orchestrator. Idempotent:
    /// a job left running across an app quit is reattached, not re-spawned.
    public func start() throws {
        try agents.bootstrap(spec())
    }

    /// Hot-reload the config (`nginx -s reload`) without dropping the listening socket. Signals the
    /// running master via its pid file, so it works regardless of who launched it.
    public func reload() throws {
        try runControlCommand(["-s", "reload"])
    }

    /// Stop the master by booting the launchd job out (so `KeepAlive` won't relaunch it).
    /// `grace` is retained for source compatibility but launchd owns the SIGTERM→SIGKILL window now.
    public func stop(grace: TimeInterval = 3.0) {
        try? agents.bootout(label)
    }

    private func spec() -> LaunchAgentSpec {
        LaunchAgentSpec(
            label: label,
            programArguments: [
                paths.nginxBinary.path,
                "-p", paths.root.path,
                "-c", paths.nginxConf.path,
                "-g", "daemon off;",
            ],
            workingDirectory: paths.root.path,
            stdoutPath: paths.nginxErrorLog.path,
            stderrPath: paths.nginxErrorLog.path)
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
