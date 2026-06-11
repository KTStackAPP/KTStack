import Foundation

/// Supervises a bundled `redis-server` as a user LaunchAgent that persists across app quit.
/// Binds loopback only (dev-insecure default); data + RDB snapshots live under app-support.
public final class RedisController: ManagedService, @unchecked Sendable {
    public let kind = ServiceKind.redis
    public var detail: String { ":6379" }
    public var logsURL: URL? { paths.serviceLog("redis") }
    public var isInstalled: Bool { catalog.isInstalled(.redis) }

    private let paths: AppSupportPaths
    private let runner: LaunchdServiceRunner
    private let catalog: ServiceBinaryCatalog
    /// Resolved from the on-demand install location (`runtimes/redis/<version>/bin/redis-server`).
    private var binary: URL? { catalog.binary(.redis, "redis-server") }

    public init(paths: AppSupportPaths, agents: LaunchAgentManager) {
        self.paths = paths
        self.catalog = ServiceBinaryCatalog(paths: paths)
        self.runner = LaunchdServiceRunner(
            kind: .redis, label: ServiceKind.redis.launchdLabel,
            preflightPorts: [6379], probe: .tcp(port: 6379), agents: agents)
    }

    public func start() async throws {
        guard let binary else { throw ServiceNotInstalled(.redis) }
        try ServiceInitializer.ensureDir(paths.serviceData("redis"))
        try writeConfig()
        try await runner.start(spec: spec(binary: binary))
    }
    public func stop() async throws { try runner.stop() }
    public func restart() async throws {
        guard let binary else { throw ServiceNotInstalled(.redis) }
        try await runner.restart(spec: spec(binary: binary))
    }
    public func probe() async -> ServiceStatus { isInstalled ? await runner.probe() : .stopped }

    private func writeConfig() throws {
        let config = """
        bind 127.0.0.1
        port 6379
        dir \(paths.serviceData("redis").path)
        logfile \(paths.serviceLog("redis").path)
        daemonize no
        save 900 1
        """
        try config.write(to: paths.serviceConfig("redis"), atomically: true, encoding: .utf8)
    }

    private func spec(binary: URL) -> LaunchAgentSpec {
        LaunchAgentSpec(
            label: kind.launchdLabel,
            programArguments: [binary.path, paths.serviceConfig("redis").path],
            workingDirectory: paths.serviceData("redis").path,
            stdoutPath: paths.serviceLog("redis").path,
            stderrPath: paths.serviceLog("redis").path)
    }
}
