import Foundation

public final class MongoDBController: ManagedService, @unchecked Sendable {
    public let kind = ServiceKind.mongodb
    public var detail: String { ":27017" }
    public var logsURL: URL? { paths.serviceLog("mongodb") }

    public var isInstalled: Bool {
        guard let binary else { return false }
        return FileManager.default.isExecutableFile(atPath: binary.path)
    }

    private let paths: AppSupportPaths
    private let runner: LaunchdServiceRunner
    private let catalog: ServiceBinaryCatalog
    
    private var binary: URL? { catalog.binary(.mongodb, "bin/mongod") }

    public init(paths: AppSupportPaths, agents: LaunchAgentManager) {
        self.paths = paths
        self.catalog = ServiceBinaryCatalog(paths: paths)
        self.runner = LaunchdServiceRunner(
            kind: .mongodb, label: ServiceKind.mongodb.launchdLabel,
            preflightPorts: [27017], probe: .tcp(port: 27017), agents: agents,
            // WiredTiger journal replay on cold start can exceed the default 8s; 15s leaves headroom
            // for a fresh-start boot while still failing fast on a real misconfiguration.
            startTimeout: 15)
    }

    public func start() async throws {
        guard let binary else { throw ServiceNotInstalled(.mongodb) }
        try ServiceInitializer.ensureDir(paths.serviceData("mongodb"))
        try await runner.start(spec: spec(binary: binary))
    }
    public func stop() async throws { try runner.stop() }
    public func restart() async throws {
        guard let binary else { throw ServiceNotInstalled(.mongodb) }
        try await runner.restart(spec: spec(binary: binary))
    }
    public func probe() async -> ServiceStatus { isInstalled ? await runner.probe() : .stopped }

    func mongoArgs(binary: URL) -> [String] {
        [binary.path,
         "--dbpath", paths.serviceData("mongodb").path,
         "--bind_ip", "127.0.0.1",
         "--port", "27017"]
    }

    private func spec(binary: URL) -> LaunchAgentSpec {
        LaunchAgentSpec(
            label: kind.launchdLabel,
            programArguments: mongoArgs(binary: binary),
            workingDirectory: paths.serviceData("mongodb").path,
            stdoutPath: paths.serviceLog("mongodb").path,
            stderrPath: paths.serviceLog("mongodb").path)
    }
}
