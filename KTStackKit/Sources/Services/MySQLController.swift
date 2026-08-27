import Foundation
import KTStackCore

// MySQL và MariaDB dùng chung controller: cùng port 3306, chỉ khác binary và cách init data dir.
public enum MySQLFlavor: Sendable {
    case mysql
    case mariadb

    var kind: ServiceKind {
        switch self {
        case .mysql: .mysql
        case .mariadb: .mariadb
        }
    }

    var serverRelPath: String {
        switch self {
        case .mysql: "bin/mysqld"
        case .mariadb: "bin/mariadbd"
        }
    }

    // MariaDB cần basedir tường minh trong config để tìm share/ và lib/plugin/ từ thư mục runtime đã move.
    var needsBasedir: Bool { self == .mariadb }
}

public final class MySQLController: ManagedService, @unchecked Sendable {
    public let kind: ServiceKind
    public var detail: String {
        ":3306"
    }

    public var logsURL: URL? {
        paths.serviceLog(name)
    }

    public var isInstalled: Bool {
        guard let binary else { return false }
        return FileManager.default.isExecutableFile(atPath: binary.path)
    }

    private let flavor: MySQLFlavor
    private let paths: AppSupportPaths
    private let runner: LaunchdServiceRunner
    private let catalog: ServiceBinaryCatalog
    private let activeVersionProvider: () -> String?

    private var name: String { flavor.kind.rawValue }

    private var binary: URL? {
        guard let v = activeVersionProvider() else { return nil }
        return catalog.binary(flavor.kind, flavor.serverRelPath, version: v)
    }

    private var basedir: URL? {
        binary?.deletingLastPathComponent().deletingLastPathComponent()
    }

    private var dataDir: URL {
        guard let v = activeVersionProvider() else { return paths.serviceData(name) }
        return paths.serviceData(name, version: v)
    }

    private var configFile: URL {
        paths.serviceConfig(name, ext: "cnf")
    }

    public init(
        paths: AppSupportPaths,
        agents: LaunchAgentManager,
        activeVersion: (() -> String?)? = nil,
        flavor: MySQLFlavor = .mysql
    ) {
        self.paths = paths
        self.flavor = flavor
        kind = flavor.kind
        let cat = ServiceBinaryCatalog(paths: paths)
        catalog = cat
        runner = LaunchdServiceRunner(
            kind: flavor.kind, label: flavor.kind.launchdLabel,
            preflightPorts: [3306], probe: .tcp(port: 3306), agents: agents
        )
        let kind = flavor.kind
        if let activeVersion {
            activeVersionProvider = activeVersion
        } else {
            activeVersionProvider = { cat.installedVersions(kind).max { $0.compare($1, options: .numeric) == .orderedAscending } }
        }
    }

    public func start() async throws {
        guard let binary else { throw ServiceNotInstalled(flavor.kind) }
        try writeConfig()
        try initializeIfNeeded(binary: binary)
        try await runner.start(spec: spec(binary: binary))
    }

    public func stop() async throws {
        try runner.stop()
    }

    public func restart() async throws {
        guard let binary else { throw ServiceNotInstalled(flavor.kind) }
        try await runner.restart(spec: spec(binary: binary))
    }

    public func probe() async -> ServiceStatus {
        isInstalled ? await runner.probe() : .stopped
    }

    private func initializeIfNeeded(binary: URL) throws {
        try ServiceInitializer.ensureDir(dataDir)
        // Cả hai flavor tạo subdir `mysql/` trong data dir, nên marker dùng chung.
        guard !ServiceInitializer.isInitialized(dataDir, marker: "mysql") else { return }
        switch flavor {
        case .mysql:
            try ServiceInitializer.run(
                binary,
                ["--defaults-file=\(configFile.path)", "--initialize-insecure"],
                tool: "mysqld"
            )
        case .mariadb:
            guard let basedir else { throw ServiceNotInstalled(.mariadb) }
            let installDB = basedir.appendingPathComponent("scripts/mariadb-install-db")
            try ServiceInitializer.run(
                installDB,
                [
                    "--basedir=\(basedir.path)",
                    "--datadir=\(dataDir.path)",
                    "--auth-root-authentication-method=normal",
                    "--skip-test-db",
                ],
                tool: "mariadb-install-db"
            )
        }
    }

    private func writeConfig() throws {
        var config = """
        [mysqld]
        port = 3306
        bind-address = 127.0.0.1
        datadir = \(dataDir.path)
        socket = \(paths.serviceSocket(name).path)
        log-error = \(paths.serviceLog(name).path)
        pid-file = \(paths.run.appendingPathComponent("\(name).pid").path)
        """
        if flavor.needsBasedir, let basedir {
            config += "\nbasedir = \(basedir.path)"
        }
        try config.write(to: configFile, atomically: true, encoding: .utf8)
    }

    private func spec(binary: URL) -> LaunchAgentSpec {
        LaunchAgentSpec(
            label: kind.launchdLabel,
            programArguments: [binary.path, "--defaults-file=\(configFile.path)"],
            workingDirectory: dataDir.path,
            stdoutPath: paths.serviceLog(name).path,
            stderrPath: paths.serviceLog(name).path
        )
    }
}
