import KTStackCore
import XCTest

final class ProcessRunnerTests: XCTestCase {
    private let runner = ProcessRunner(terminationGrace: 0.5, drainGrace: 1)

    func testMegabyteOfStderrCompletesWithoutDeadlock() throws {
        let exe = try FakeExecutable.emittingStderr(bytes: 1_048_576)
        defer { exe.remove() }
        let result = try runner.run(exe.path, timeout: 30)
        XCTAssertNil(result.interruption)
        XCTAssertEqual(result.status, 0)
        XCTAssertEqual(result.stderr.count, 1_048_576)
    }

    func testLargeStdoutAndStderrDrainConcurrently() throws {
        let exe = try FakeExecutable.make(
            named: "both",
            script: "head -c 1048576 /dev/zero\nhead -c 1048576 /dev/zero >&2"
        )
        defer { exe.remove() }
        let result = try runner.run(exe.path, timeout: 30)
        XCTAssertTrue(result.succeeded)
        XCTAssertEqual(result.stdout.count, 1_048_576)
        XCTAssertEqual(result.stderr.count, 1_048_576)
    }

    func testTimeoutEscalatesToKillWhenTermIsIgnored() throws {
        let exe = try FakeExecutable.make(named: "stubborn", script: "trap '' TERM\nexec /bin/sleep 60")
        defer { exe.remove() }
        let started = Date()
        let result = try runner.run(exe.path, timeout: 0.5)
        XCTAssertEqual(result.interruption, .timedOut)
        XCTAssertFalse(result.succeeded)
        XCTAssertLessThan(Date().timeIntervalSince(started), 10)
    }

    func testExitCodeAndArgumentsPassThrough() throws {
        let exe = try FakeExecutable.make(named: "echoer", script: "printf '%s|%s' \"$1\" \"$2\"\nexit 4")
        defer { exe.remove() }
        let result = try runner.run(exe.path, ["a b", "$HOME"])
        XCTAssertEqual(result.status, 4)
        XCTAssertEqual(result.stdoutText, "a b|$HOME")
        XCTAssertNil(result.interruption)
    }

    func testStandardInputIsDelivered() throws {
        let result = try runner.run(ProcessRequest(executable: "/bin/cat", standardInput: Data("piped".utf8), timeout: 10))
        XCTAssertEqual(result.stdoutText, "piped")
    }

    func testRelativeExecutableIsRejected() {
        XCTAssertThrowsError(try runner.run("ls")) { error in
            XCTAssertEqual(error as? ProcessRunnerError, .executableNotAbsolute("ls"))
        }
    }

    func testMissingExecutableFailsToLaunch() {
        XCTAssertThrowsError(try runner.run("/nonexistent/ktstack-\(UUID().uuidString)")) { error in
            guard case .launchFailed = error as? ProcessRunnerError else {
                return XCTFail("unexpected error \(error)")
            }
        }
    }

    func testAsyncVariantReturnsOutput() async throws {
        let result = try await runner.runAsync("/bin/echo", ["async"], timeout: 10)
        XCTAssertTrue(result.succeeded)
        XCTAssertEqual(result.stdoutText, "async\n")
    }

    func testAsyncVariantTimesOut() async throws {
        let result = try await runner.runAsync("/bin/sleep", ["60"], timeout: 0.3)
        XCTAssertEqual(result.interruption, .timedOut)
    }

    func testAsyncCancellationTerminatesProcess() async throws {
        let task = Task { try await runner.runAsync("/bin/sleep", ["60"]) }
        try await Task.sleep(nanoseconds: 300_000_000)
        task.cancel()
        let result = try await task.value
        XCTAssertEqual(result.interruption, .cancelled)
    }

    func testBlockingRunsFromEveryCooperativeThreadStillComplete() async throws {
        let runner = runner
        let width = ProcessInfo.processInfo.activeProcessorCount * 2
        let outputs = try await withThrowingTaskGroup(of: String.self) { group in
            for index in 0 ..< width {
                group.addTask { try runner.run("/bin/echo", ["\(index)"], timeout: 10).stdoutText }
            }
            return try await group.reduce(into: [String]()) { $0.append($1) }
        }
        XCTAssertEqual(outputs.count, width)
    }

    func testBackgroundChildHoldingThePipeDoesNotBlockPastTheDrainGrace() throws {
        let exe = try FakeExecutable.make(named: "forker", script: "/bin/sleep 30 &\necho parent")
        defer { exe.remove() }
        let started = Date()
        let result = try runner.run(exe.path, timeout: 10)
        XCTAssertEqual(result.status, 0)
        XCTAssertTrue(result.stdoutText.hasPrefix("parent"))
        XCTAssertLessThan(Date().timeIntervalSince(started), 10)
    }

    func testRepeatedRunsDoNotLeakDescriptors() throws {
        _ = try runner.run("/usr/bin/true")
        let delta = try FileDescriptorCounter.delta {
            for _ in 0 ..< 10 {
                _ = try runner.run("/bin/echo", ["x"], timeout: 10)
            }
        }
        XCTAssertLessThanOrEqual(delta, 0)
    }
}
