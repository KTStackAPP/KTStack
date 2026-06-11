import Foundation

/// Supervises a bundled `postgres` as a user LaunchAgent that persists across app quit. First run
/// runs `initdb` (trust auth, no password) into an app-support datadir — a documented dev-only
/// default. Listens on loopback only; the unix socket lives under `run/`.
public final class PostgreSQLController: ManagedService, @unchecked Sendable {
    public let kind = ServiceKind.postgres
    public var detail: String { ":5432" }
    public var logsURL: URL? { paths.serviceLog("postgres") }
    /// Installed when the on-demand tree contains both `postgres` (the catalog marker) and `initdb`.
    public var isInstalled: Bool {
        guard let initdb else { return false }    // non-nil only when the postgres marker is present
        return FileManager.default.isExecutableFile(atPath: initdb.path)
    }

    private let paths: AppSupportPaths
    private let runner: LaunchdServiceRunner
    private let catalog: ServiceBinaryCatalog
    private var binary: URL? { catalog.binary(.postgres, "bin/postgres") }
    private var initdb: URL? { catalog.binary(.postgres, "bin/initdb") }
    private var dataDir: URL { paths.serviceData("postgres") }

    public init(paths: AppSupportPaths, agents: LaunchAgentManager) {
        self.paths = paths
        self.catalog = ServiceBinaryCatalog(paths: paths)
        self.runner = LaunchdServiceRunner(
            kind: .postgres, label: ServiceKind.postgres.launchdLabel,
            preflightPorts: [5432], probe: .tcp(port: 5432), agents: agents)
    }

    public func start() async throws {
        guard let binary, let initdb else { throw ServiceNotInstalled(.postgres) }
        try initializeIfNeeded(initdb: initdb)
        try await runner.start(spec: spec(binary: binary))
    }
    public func stop() async throws { try runner.stop() }
    public func restart() async throws {
        guard let binary else { throw ServiceNotInstalled(.postgres) }
        try await runner.restart(spec: spec(binary: binary))
    }
    public func probe() async -> ServiceStatus { isInstalled ? await runner.probe() : .stopped }

    /// `PG_VERSION` is initdb's completion sentinel.
    private func initializeIfNeeded(initdb: URL) throws {
        try ServiceInitializer.ensureDir(dataDir)
        guard !ServiceInitializer.isInitialized(dataDir, marker: "PG_VERSION") else { return }
        try ServiceInitializer.run(
            initdb,
            ["-D", dataDir.path, "-U", "postgres", "--auth=trust", "--encoding=UTF8"],
            tool: "initdb")
    }

    private func spec(binary: URL) -> LaunchAgentSpec {
        // `-k <run>` puts the unix socket under run/; `listen_addresses` binds loopback TCP only.
        LaunchAgentSpec(
            label: kind.launchdLabel,
            programArguments: [
                binary.path,
                "-D", dataDir.path,
                "-p", "5432",
                "-k", paths.run.path,
                "-c", "listen_addresses=127.0.0.1",
                "-c", "logging_collector=off",
            ],
            workingDirectory: dataDir.path,
            stdoutPath: paths.serviceLog("postgres").path,
            stderrPath: paths.serviceLog("postgres").path)
    }
}
