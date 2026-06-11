import Foundation

/// Supervises a bundled `mysqld` as a user LaunchAgent that persists across app quit. First run
/// initializes an insecure (no root password) datadir under app-support — a documented dev-only
/// default. Binds loopback only. GPLv2 attribution is a Phase 9 NOTICE formality (free distribution).
public final class MySQLController: ManagedService, @unchecked Sendable {
    public let kind = ServiceKind.mysql
    public var detail: String { ":3306" }
    public var logsURL: URL? { paths.serviceLog("mysql") }
    public var isInstalled: Bool { FileManager.default.isExecutableFile(atPath: binary.path) }

    private let paths: AppSupportPaths
    private let runner: LaunchdServiceRunner
    private var binary: URL { paths.binary("mysqld") }
    private var dataDir: URL { paths.serviceData("mysql") }
    private var configFile: URL { paths.serviceConfig("mysql", ext: "cnf") }

    public init(paths: AppSupportPaths, agents: LaunchAgentManager) {
        self.paths = paths
        self.runner = LaunchdServiceRunner(
            kind: .mysql, label: ServiceKind.mysql.launchdLabel,
            preflightPorts: [3306], probe: .tcp(port: 3306), agents: agents)
    }

    public func start() async throws {
        guard isInstalled else { throw ServiceNotInstalled(.mysql) }
        try writeConfig()
        try initializeIfNeeded()
        try await runner.start(spec: spec())
    }
    public func stop() async throws { try runner.stop() }
    public func restart() async throws {
        guard isInstalled else { throw ServiceNotInstalled(.mysql) }
        try await runner.restart(spec: spec())
    }
    public func probe() async -> ServiceStatus { isInstalled ? await runner.probe() : .stopped }

    /// `mysqld --initialize-insecure` builds the system tables on first run (datadir must be empty).
    /// `mysql` subdir is the sentinel that init has completed.
    private func initializeIfNeeded() throws {
        try ServiceInitializer.ensureDir(dataDir)
        guard !ServiceInitializer.isInitialized(dataDir, marker: "mysql") else { return }
        try ServiceInitializer.run(
            binary,
            ["--defaults-file=\(configFile.path)", "--initialize-insecure"],
            tool: "mysqld")
    }

    private func writeConfig() throws {
        let config = """
        [mysqld]
        port = 3306
        bind-address = 127.0.0.1
        datadir = \(dataDir.path)
        socket = \(paths.serviceSocket("mysql").path)
        log-error = \(paths.serviceLog("mysql").path)
        pid-file = \(paths.run.appendingPathComponent("mysql.pid").path)
        """
        try config.write(to: configFile, atomically: true, encoding: .utf8)
    }

    private func spec() -> LaunchAgentSpec {
        LaunchAgentSpec(
            label: kind.launchdLabel,
            programArguments: [binary.path, "--defaults-file=\(configFile.path)"],
            workingDirectory: dataDir.path,
            stdoutPath: paths.serviceLog("mysql").path,
            stderrPath: paths.serviceLog("mysql").path)
    }
}
