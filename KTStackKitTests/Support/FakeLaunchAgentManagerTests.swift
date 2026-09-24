import KTStackCore
import XCTest
@testable import KTStackKit

final class FakeLaunchAgentManagerTests: XCTestCase {
    private let label = "com.ktstack.fake-service"
    private var root: URL!
    private var paths: AppSupportPaths!

    override func setUpWithError() throws {
        root = FileManager.default.temporaryDirectory.appendingPathComponent("ktstack-fake-agents-\(UUID().uuidString)")
        paths = AppSupportPaths(root: root)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: root)
    }

    func testRealManagerSatisfiesSeam() {
        let seam: any LaunchAgentManaging = LaunchAgentManager(paths: paths)
        XCTAssertNotNil(seam as? LaunchAgentManager)
    }

    func testRunnerStopBootsOutThroughSeam() throws {
        let fake = FakeLaunchAgentManager(paths: paths, loaded: [label])
        try runner(fake, port: 1).stop()
        XCTAssertEqual(fake.calls, [.bootout(label)])
        XCTAssertFalse(fake.isLoaded(label))
    }

    func testRunnerRestartBootstrapsWhenNotLoaded() async throws {
        let listener = try LoopbackListener()
        defer { listener.close() }
        let fake = FakeLaunchAgentManager(paths: paths)
        try await runner(fake, port: listener.port).restart(spec: spec())
        XCTAssertEqual(fake.calls, [.writePlist(label), .bootstrap(label)])
        XCTAssertTrue(fake.isLoaded(label))
    }

    func testRunnerRestartKickstartsWhenLoaded() async throws {
        let listener = try LoopbackListener()
        defer { listener.close() }
        let fake = FakeLaunchAgentManager(paths: paths, loaded: [label])
        try await runner(fake, port: listener.port).restart(spec: spec())
        XCTAssertEqual(fake.calls, [.writePlist(label), .kickstart(label)])
    }

    func testInjectedFailureSurfacesFromRunner() {
        let fake = FakeLaunchAgentManager(paths: paths, loaded: [label])
        fake.fail(.bootout, with: LaunchdServiceRunner.error("boom"))
        XCTAssertThrowsError(try runner(fake, port: 1).stop())
        XCTAssertTrue(fake.isLoaded(label))
    }

    private func runner(_ agents: FakeLaunchAgentManager, port: Int) -> LaunchdServiceRunner {
        LaunchdServiceRunner(
            kind: .redis,
            label: label,
            preflightPorts: [port],
            probe: .tcp(port: port),
            agents: agents,
            startTimeout: 2
        )
    }

    private func spec() -> LaunchAgentSpec {
        LaunchAgentSpec(label: label, programArguments: ["/usr/bin/true"])
    }
}
