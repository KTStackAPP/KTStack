import Foundation
import KTStackCore

// Identity of one nginx process: the front terminator or a per-site backend.
// Lets a single NginxController type drive both without hardcoding the front's paths.
public struct NginxInstance: Sendable {
    public let label: String
    public let confFile: URL
    public let prefix: URL
    public let errorLog: URL

    public init(label: String, confFile: URL, prefix: URL, errorLog: URL) {
        self.label = label
        self.confFile = confFile
        self.prefix = prefix
        self.errorLog = errorLog
    }

    // Today's single front nginx: the exact label/paths the controller used to hardcode.
    public static func front(paths: AppSupportPaths) -> NginxInstance {
        NginxInstance(
            label: ServiceKind.nginx.launchdLabel,
            confFile: paths.nginxConf,
            prefix: paths.root,
            errorLog: paths.nginxErrorLog
        )
    }
}

public final class NginxController: @unchecked Sendable {
    public enum ControlError: LocalizedError, Equatable {
        case commandFailed([String], Int32, String)

        public var errorDescription: String? {
            switch self {
            case let .commandFailed(args, code, output):
                let detail = output.trimmingCharacters(in: .whitespacesAndNewlines)
                let command = (["nginx"] + args).joined(separator: " ")
                if detail.isEmpty { return "\(command) failed with exit code \(code)." }
                return "\(command) failed with exit code \(code): \(detail)"
            }
        }
    }

    private let paths: AppSupportPaths
    private let agents: LaunchAgentManager
    private let instance: NginxInstance
    private static let fileDescriptorLimit = 8192
    private var cachedBuildInfo: String?

    public init(paths: AppSupportPaths, agents: LaunchAgentManager, instance: NginxInstance? = nil) {
        self.paths = paths
        self.agents = agents
        self.instance = instance ?? .front(paths: paths)
    }

    public var isRunning: Bool {
        agents.isLoaded(instance.label)
    }

    // Hỏi thẳng launchctl: cache lạnh trả false ngay sau khi app mở dù nginx đang chạy.
    public var isRunningNow: Bool {
        agents.isLoadedNow(instance.label)
    }

    public func test() throws {
        try runControlCommand(["-t"])
    }

    public func start() throws {
        try test()
        try agents.bootstrap(spec())
    }

    public func reload() throws {
        try test()
        try runControlCommand(["-s", "reload"])
    }

    public func restart() throws {
        try test()
        stop()
        try start()
    }

    public func supportsResponseBodyRewrite() -> Bool {
        buildInfo().contains("http_sub_module")
    }

    private func buildInfo() -> String {
        if let cachedBuildInfo { return cachedBuildInfo }
        let res = try? ProcessRunner().run(paths.nginxBinary.path, ["-V"], timeout: ToolTimeout.configTest)
        let info = res.map { $0.stdoutText + $0.stderrText } ?? ""
        cachedBuildInfo = info
        return info
    }

    public func stop(grace _: TimeInterval = 3.0) {
        try? agents.bootout(instance.label)
    }

    private func spec() -> LaunchAgentSpec {
        LaunchAgentSpec(
            label: instance.label,
            programArguments: [
                paths.nginxBinary.path,
                "-p", instance.prefix.path,
                "-c", instance.confFile.path,
                "-g", "daemon off;",
            ],
            workingDirectory: instance.prefix.path,
            stdoutPath: instance.errorLog.path,
            stderrPath: instance.errorLog.path,
            fileDescriptorLimit: Self.fileDescriptorLimit
        )
    }

    private func runControlCommand(_ extra: [String]) throws {
        let args = ["-p", instance.prefix.path, "-c", instance.confFile.path] + extra
        let res = try ProcessRunner().run(paths.nginxBinary.path, args, timeout: ToolTimeout.configTest)
        guard res.succeeded else {
            let output = res.interruption == .timedOut ? "timed out" : res.stderrText
            throw ControlError.commandFailed(extra, res.status, output)
        }
    }
}
