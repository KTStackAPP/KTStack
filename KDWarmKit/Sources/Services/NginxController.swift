import Foundation

public final class NginxController: @unchecked Sendable {
    private let paths: AppSupportPaths
    private let agents: LaunchAgentManager
    private let label = ServiceKind.nginx.launchdLabel

    public init(paths: AppSupportPaths, agents: LaunchAgentManager) {
        self.paths = paths
        self.agents = agents
    }

   
    public var isRunning: Bool { agents.isLoaded(label) }

    public func start() throws {
        try agents.bootstrap(spec())
    }

   
    public func reload() throws {
        try runControlCommand(["-s", "reload"])
    }

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
