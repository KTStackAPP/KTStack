import Darwin
import KTStackCore
import XCTest
@testable import KTStackKit

final class EngineVersionSwitchTests: XCTestCase {
    private let label = "com.ktstack.version-switch-test"
    private let oldProgram = ["/old/runtime/redis/7.2/bin/redis-server", "/old/redis.conf"]
    private var root: URL!
    private var paths: AppSupportPaths!

    override func setUpWithError() throws {
        root = FileManager.default.temporaryDirectory.appendingPathComponent("kt-switch-\(UUID().uuidString)")
        paths = AppSupportPaths(root: root)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: root)
    }

    private func runner(_ agents: FakeLaunchAgentManager, port: Int) -> LaunchdServiceRunner {
        LaunchdServiceRunner(
            kind: .redis, label: label, preflightPorts: [port], probe: .tcp(port: port),
            agents: agents, startTimeout: 2
        )
    }

    private func spec() -> LaunchAgentSpec {
        LaunchAgentSpec(label: label, programArguments: ["/usr/bin/true"])
    }

    private func staleAgents() -> FakeLaunchAgentManager {
        let agents = FakeLaunchAgentManager(paths: paths)
        agents.markLoaded(label)
        agents.setLoadedArguments(oldProgram, for: label)
        agents.setJobPID(getpid(), for: label)
        return agents
    }

    func testRestartBootsOutAJobRunningAnotherBinary() async throws {
        let listener = try LoopbackListener()
        defer { listener.close() }
        let agents = staleAgents()
        try await runner(agents, port: listener.port).restart(spec: spec())
        XCTAssertEqual(agents.calls.filter { $0 != .writePlist(label) }, [.bootout(label), .bootstrap(label)])
        XCTAssertEqual(agents.loadedProgramArguments(label), spec().programArguments)
    }

    func testStartDoesNotKeepAHealthyJobRunningAnotherBinary() async throws {
        let listener = try LoopbackListener()
        defer { listener.close() }
        let agents = staleAgents()
        _ = try? await runner(agents, port: listener.port).start(spec: spec())
        XCTAssertTrue(agents.calls.contains(.bootout(label)))
        XCTAssertFalse(agents.calls.contains(.kickstart(label)))
    }

    func testStartKeepsAHealthyJobRunningTheSameBinary() async throws {
        let listener = try LoopbackListener()
        defer { listener.close() }
        let agents = staleAgents()
        agents.setLoadedArguments(spec().programArguments, for: label)
        try await runner(agents, port: listener.port).start(spec: spec())
        XCTAssertTrue(agents.calls.isEmpty)
    }

    func testParsesArgumentsFromLaunchctlPrint() {
        let output = """
        gui/501/com.ktstack.mysql = {
        \tactive count = 1
        \targuments = {
        \t\t/Users/me/Library/Application Support/KTStack/runtimes/mysql/9.6/bin/mysqld
        \t\t--defaults-file=/Users/me/Library/Application Support/KTStack/config/mysql-9.6.cnf
        \t}
        \tpid = 4242
        }
        """
        XCTAssertEqual(LaunchAgentManager.parseArguments(from: output), [
            "/Users/me/Library/Application Support/KTStack/runtimes/mysql/9.6/bin/mysqld",
            "--defaults-file=/Users/me/Library/Application Support/KTStack/config/mysql-9.6.cnf",
        ])
        XCTAssertNil(LaunchAgentManager.parseArguments(from: "state = not running"))
    }

    func testMarkerIsWrittenThenBlocksAnIncompatibleVersion() throws {
        let dir = root.appendingPathComponent("mysql-data")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        try DataDirVersionMarker.verify(dir, version: "8.4.2", kind: .mysql)
        XCTAssertEqual(DataDirVersionMarker.recordedVersion(in: dir, kind: .mysql), "8.4.2")
        XCTAssertNoThrow(try DataDirVersionMarker.verify(dir, version: "8.4.5", kind: .mysql))
        XCTAssertThrowsError(try DataDirVersionMarker.verify(dir, version: "9.6.0", kind: .mysql)) { error in
            XCTAssertTrue(error.localizedDescription.contains("8.4.2"), error.localizedDescription)
        }
        XCTAssertNoThrow(try DataDirVersionMarker.verify(dir, version: nil, kind: .mysql))
    }

    func testPostgresComparesMajorVersionFromPGVersion() throws {
        let dir = root.appendingPathComponent("pg-data")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        try "16\n".write(to: dir.appendingPathComponent("PG_VERSION"), atomically: true, encoding: .utf8)
        XCTAssertNoThrow(try DataDirVersionMarker.verify(dir, version: "16.4", kind: .postgres))
        XCTAssertThrowsError(try DataDirVersionMarker.verify(dir, version: "17.2", kind: .postgres))
    }
}
