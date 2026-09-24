import Foundation
import KTStackCore

// Lifecycle for one per-site Apache backend over launchd. httpd runs in the foreground
// (launchd supervises it) with ServerRoot at the relocated install and a per-site config.
// Teardown is by launchd label (handled by SiteBackendSupervisor), never by binary path.
public final class ApacheController: @unchecked Sendable {
    public enum ControlError: LocalizedError, Equatable {
        case commandFailed([String], Int32, String)

        public var errorDescription: String? {
            switch self {
            case let .commandFailed(args, code, output):
                let detail = output.trimmingCharacters(in: .whitespacesAndNewlines)
                let command = (["httpd"] + args).joined(separator: " ")
                return detail.isEmpty
                    ? "\(command) failed with exit code \(code)."
                    : "\(command) failed with exit code \(code): \(detail)"
            }
        }
    }

    private let paths: AppSupportPaths
    private let agents: LaunchAgentManager
    private let label: String
    private let conf: URL
    private let errorLog: URL
    private static let fileDescriptorLimit = 8192

    public init(paths: AppSupportPaths, agents: LaunchAgentManager, label: String, conf: URL, errorLog: URL) {
        self.paths = paths
        self.agents = agents
        self.label = label
        self.conf = conf
        self.errorLog = errorLog
    }

    public var isRunning: Bool {
        agents.isLoaded(label)
    }

    // `httpd -t`. Fail-closed: start/reload validate before launching or signaling, so a bad conf
    // surfaces an error instead of a crash-looping backend the front would 502 into.
    public func test() throws {
        try runControlCommand(["-t"])
    }

    public func start() throws {
        try test()
        try agents.bootstrap(spec())
    }

    // graceful does not re-open Listen sockets, so a port change never rides a reload; the engine
    // swap starts a fresh process on the new port and reaps the old one instead.
    public func reload() throws {
        try test()
        try runControlCommand(["-k", "graceful"])
    }

    public func stop() {
        try? agents.bootout(label)
    }

    private func spec() -> LaunchAgentSpec {
        LaunchAgentSpec(
            label: label,
            programArguments: [
                paths.apacheBinary.path,
                "-d", paths.apacheRoot.path,
                "-f", conf.path,
                "-D", "FOREGROUND",
            ],
            workingDirectory: paths.apacheRoot.path,
            stdoutPath: errorLog.path,
            stderrPath: errorLog.path,
            fileDescriptorLimit: Self.fileDescriptorLimit
        )
    }

    private func runControlCommand(_ extra: [String]) throws {
        let args = ["-d", paths.apacheRoot.path, "-f", conf.path] + extra
        let res = try ProcessRunner().run(paths.apacheBinary.path, args, timeout: ToolTimeout.configTest)
        guard res.succeeded else {
            let output = res.interruption == .timedOut ? "timed out" : res.stderrText
            throw ControlError.commandFailed(extra, res.status, output)
        }
    }
}
