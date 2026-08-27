import Foundation
import KTStackCore

// Cache in-memory thuần: không config, không data dir. launchd chạy foreground (-v để log ra stderr).
public final class MemcachedController: ManagedService, @unchecked Sendable {
    public let kind = ServiceKind.memcached
    public var detail: String {
        ":11211"
    }

    public var logsURL: URL? {
        paths.serviceLog("memcached")
    }

    public var isInstalled: Bool {
        guard let binary else { return false }
        return FileManager.default.isExecutableFile(atPath: binary.path)
    }

    private let paths: AppSupportPaths
    private let runner: LaunchdServiceRunner
    private let catalog: ServiceBinaryCatalog
    private let activeVersionProvider: () -> String?

    private var binary: URL? {
        guard let v = activeVersionProvider() else { return nil }
        return catalog.binary(.memcached, "bin/memcached", version: v)
    }

    public init(
        paths: AppSupportPaths,
        agents: LaunchAgentManager,
        activeVersion: (() -> String?)? = nil
    ) {
        self.paths = paths
        let cat = ServiceBinaryCatalog(paths: paths)
        catalog = cat
        runner = LaunchdServiceRunner(
            kind: .memcached, label: ServiceKind.memcached.launchdLabel,
            preflightPorts: [11211], probe: .tcp(port: 11211), agents: agents
        )
        if let activeVersion {
            activeVersionProvider = activeVersion
        } else {
            activeVersionProvider = { cat.installedVersions(.memcached).max { $0.compare($1, options: .numeric) == .orderedAscending } }
        }
    }

    public func start() async throws {
        guard let binary else { throw ServiceNotInstalled(.memcached) }
        try await runner.start(spec: spec(binary: binary))
    }

    public func stop() async throws {
        try runner.stop()
    }

    public func restart() async throws {
        guard let binary else { throw ServiceNotInstalled(.memcached) }
        try await runner.restart(spec: spec(binary: binary))
    }

    public func probe() async -> ServiceStatus {
        isInstalled ? await runner.probe() : .stopped
    }

    private func spec(binary: URL) -> LaunchAgentSpec {
        LaunchAgentSpec(
            label: kind.launchdLabel,
            programArguments: [binary.path, "-l", "127.0.0.1", "-p", "11211", "-m", "64", "-v"],
            workingDirectory: paths.run.path,
            stdoutPath: paths.serviceLog("memcached").path,
            stderrPath: paths.serviceLog("memcached").path
        )
    }
}
