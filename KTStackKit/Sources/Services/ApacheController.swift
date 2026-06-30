import Foundation

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

    public func start() throws {
        try agents.bootstrap(spec())
    }

    public func reload() throws {
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
        let proc = Process()
        proc.executableURL = paths.apacheBinary
        proc.arguments = ["-d", paths.apacheRoot.path, "-f", conf.path] + extra
        proc.standardOutput = FileHandle.nullDevice
        let pipe = Pipe()
        proc.standardError = pipe
        try proc.run()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        proc.waitUntilExit()
        guard proc.terminationStatus == 0 else {
            let output = String(data: data, encoding: .utf8) ?? ""
            throw ControlError.commandFailed(extra, proc.terminationStatus, output)
        }
    }
}
