import KTStackCore
import XCTest

final class WorkerBackoffTests: XCTestCase {
    func testQuickExitsBackOffExponentiallyThenGiveUp() {
        var policy = WorkerBackoff(initialDelay: 1, maxDelay: 10, stableRuntime: 60, maxQuickExits: 6)
        let decisions = (0..<6).map { _ in policy.record(runtime: 2) }
        XCTAssertEqual(decisions, [
            .restart(after: 1), .restart(after: 2), .restart(after: 4),
            .restart(after: 8), .restart(after: 10), .giveUp,
        ])
    }

    func testStableRunResetsTheBackoff() {
        var policy = WorkerBackoff(initialDelay: 1, maxDelay: 60, stableRuntime: 60, maxQuickExits: 8)
        _ = policy.record(runtime: 1)
        _ = policy.record(runtime: 1)
        XCTAssertEqual(policy.record(runtime: 3600), .restart(after: 1))
        XCTAssertEqual(policy.quickExits, 0)
        XCTAssertEqual(policy.record(runtime: 1), .restart(after: 1))
    }
}

final class WorkerSupervisorTests: XCTestCase {
    private var directory: URL!

    override func setUpWithError() throws {
        directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("ktstack-worker-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: directory)
    }

    private var statusURL: URL { directory.appendingPathComponent("status/worker.json") }

    private func supervisor(maxQuickExits: Int = 3) -> WorkerSupervisor {
        WorkerSupervisor(
            parentPID: getpid(),
            statusURL: statusURL,
            backoff: WorkerBackoff(initialDelay: 0.01, maxDelay: 0.05, stableRuntime: 30, maxQuickExits: maxQuickExits),
            pollInterval: 0.05,
            gracePeriod: 1
        )
    }

    func testCommandLineRoundTripsThroughParse() throws {
        let line = WorkerSupervisor.commandLine(
            parentPID: 4242, statusURL: statusURL, executable: "/usr/bin/php", arguments: ["artisan", "queue:work"]
        )
        XCTAssertEqual(line.first, WorkerSupervisor.command)
        let parsed = try XCTUnwrap(WorkerSupervisor.parse(Array(line.dropFirst())))
        XCTAssertEqual(parsed.supervisor.parentPID, 4242)
        XCTAssertEqual(parsed.supervisor.statusURL.path, statusURL.path)
        XCTAssertEqual(parsed.executable, "/usr/bin/php")
        XCTAssertEqual(parsed.arguments, ["artisan", "queue:work"])
    }

    func testParseRejectsMissingStatusOrUnknownFlags() {
        XCTAssertNil(WorkerSupervisor.parse(["--parent-pid", "4242", "--", "/bin/true"]))
        XCTAssertNil(WorkerSupervisor.parse(["--parent-pid", "4242", "--status", "/tmp/s", "--x", "1", "--", "/bin/true"]))
        XCTAssertNil(WorkerSupervisor.parse(["--parent-pid", "1", "--status", "/tmp/s", "--", "/bin/true"]))
    }

    func testCrashingWorkerIsRestartedThenMarkedCrashed() throws {
        let failing = try FakeExecutable.make(named: "failing", script: "exit 3", in: directory)
        let code = supervisor(maxQuickExits: 3).run(executable: failing.path, arguments: [], listensForTermination: false)
        XCTAssertEqual(code, 0)
        let status = try XCTUnwrap(WorkerStatus.read(from: statusURL))
        XCTAssertEqual(status.state, .crashed)
        XCTAssertEqual(status.restarts, 2)
        XCTAssertEqual(status.lastExitStatus, 3)
        XCTAssertNil(status.pid)
    }

    func testMissingExecutableCountsAsAQuickExit() throws {
        let missing = directory.appendingPathComponent("missing").path
        _ = supervisor(maxQuickExits: 2).run(executable: missing, arguments: [], listensForTermination: false)
        let status = try XCTUnwrap(WorkerStatus.read(from: statusURL))
        XCTAssertEqual(status.state, .crashed)
        XCTAssertEqual(status.lastExitStatus, 127)
    }

    func testStopRequestTerminatesTheRunningWorker() throws {
        let sleeper = try FakeExecutable.make(named: "sleeper", script: "exec /bin/sleep 30", in: directory)
        let stop = WorkerStopSignal()
        let runner = supervisor()
        let finished = expectation(description: "supervisor returned")
        let url = statusURL
        DispatchQueue.global().async {
            _ = runner.run(executable: sleeper.path, arguments: [], stop: stop, listensForTermination: false)
            finished.fulfill()
        }
        let deadline = Date().addingTimeInterval(5)
        while WorkerStatus.read(from: url)?.state != .running, Date() < deadline {
            Thread.sleep(forTimeInterval: 0.05)
        }
        let running = try XCTUnwrap(WorkerStatus.read(from: url))
        XCTAssertEqual(running.state, .running)
        let pid = try XCTUnwrap(running.pid)
        stop.request()
        wait(for: [finished], timeout: 5)
        XCTAssertEqual(WorkerStatus.read(from: url)?.state, .stopped)
        XCTAssertNotEqual(kill(pid, 0), 0, "the worker process is gone after a stop")
    }

    func testResolvesExecutablesFromPathAndWorkingDirectory() throws {
        let tool = try FakeExecutable.make(named: "horizon", script: "exit 0", in: directory.appendingPathComponent("bin"))
        XCTAssertEqual(
            WorkerExecutable.resolve("horizon", searchPath: "/nonexistent:\(directory.appendingPathComponent("bin").path)", workingDirectory: "/"),
            tool.path
        )
        XCTAssertEqual(WorkerExecutable.resolve("bin/horizon", searchPath: nil, workingDirectory: directory.path), tool.path)
        XCTAssertNil(WorkerExecutable.resolve("horizon", searchPath: "/nonexistent", workingDirectory: "/"))
    }
}
