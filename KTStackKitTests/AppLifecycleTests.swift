import KTStackCore
import XCTest
@testable import KTStackKit

final class AppLifecycleTests: XCTestCase {
    override func tearDown() {
        AppTermination.reset()
        super.tearDown()
    }

    func testRelaunchArgumentsRoundTrip() {
        let args = ["/Applications/KTStack.app/Contents/MacOS/KTStack"] + RelaunchGate.arguments(waitingFor: 4242)
        XCTAssertEqual(RelaunchGate.pidToWaitFor(in: args), 4242)
        XCTAssertNil(RelaunchGate.pidToWaitFor(in: ["KTStack"]))
        XCTAssertNil(RelaunchGate.pidToWaitFor(in: ["KTStack", RelaunchGate.flag]))
        XCTAssertNil(RelaunchGate.pidToWaitFor(in: ["KTStack", RelaunchGate.flag, String(getpid())]))
    }

    func testWaitReturnsOnceOldInstanceExits() {
        var polls = 0
        let exited = RelaunchGate.waitForExit(of: 4242, timeout: 5) { _ in
            polls += 1
            return polls < 3
        }
        XCTAssertTrue(exited)
        XCTAssertEqual(polls, 3)
    }

    func testWaitGivesUpAfterTimeout() {
        XCTAssertFalse(RelaunchGate.waitForExit(of: 4242, timeout: 0.1) { _ in true })
    }

    func testWaitsForRealChildProcess() throws {
        let child = Process()
        child.executableURL = URL(fileURLWithPath: "/bin/sleep")
        child.arguments = ["0.3"]
        try child.run()
        XCTAssertTrue(RelaunchGate.processIsAlive(child.processIdentifier))
        XCTAssertTrue(RelaunchGate.waitForExit(of: child.processIdentifier, timeout: 5) { _ in child.isRunning })
    }

    func testBootstrapRefusedWhileTerminating() throws {
        let paths = AppSupportPaths(root: URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("ktstack-term-\(UUID().uuidString)"))
        defer { try? FileManager.default.removeItem(at: paths.root) }
        AppTermination.begin()
        let spec = LaunchAgentSpec(label: "com.ktstack.test.terminating", programArguments: ["/usr/bin/true"])
        XCTAssertThrowsError(try LaunchAgentManager(paths: paths).bootstrap(spec)) { error in
            XCTAssertTrue(error is AppTermination.Refused)
        }
        XCTAssertFalse(FileManager.default.fileExists(atPath: paths.launchAgentPlist(spec.label).path))
    }
}
