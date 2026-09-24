import Darwin
import KTStackCore
import XCTest
@testable import KTStackKit

final class TestSupportTests: XCTestCase {
    func testDescriptorCounterSeesOpenAndClose() throws {
        let baseline = FileDescriptorCounter.openCount()
        XCTAssertGreaterThan(baseline, 0)
        var fds: [Int32] = [0, 0]
        XCTAssertEqual(pipe(&fds), 0)
        XCTAssertEqual(FileDescriptorCounter.openCount(), baseline + 2)
        close(fds[0])
        close(fds[1])
        XCTAssertEqual(FileDescriptorCounter.openCount(), baseline)
    }

    func testDescriptorDeltaReportsLeak() {
        var leaked: Int32 = -1
        let delta = FileDescriptorCounter.delta { leaked = open("/dev/null", O_RDONLY) }
        XCTAssertEqual(delta, 1)
        close(leaked)
        XCTAssertEqual(FileDescriptorCounter.delta { close(open("/dev/null", O_RDONLY)) }, 0)
    }

    func testFakeExecutableRunsScriptWithExitCode() throws {
        let exe = try FakeExecutable.make(named: "fake-tool", script: "echo \"$1\"\nexit 3")
        defer { exe.remove() }
        let proc = Process()
        proc.executableURL = exe.url
        proc.arguments = ["hello"]
        let pipe = Pipe()
        proc.standardOutput = pipe
        try proc.run()
        let out = pipe.fileHandleForReading.readDataToEndOfFile()
        proc.waitUntilExit()
        XCTAssertEqual(proc.terminationStatus, 3)
        XCTAssertEqual(String(decoding: out, as: UTF8.self), "hello\n")
    }

    func testFakeExecutableEmitsRequestedStderrVolume() throws {
        let exe = try FakeExecutable.emittingStderr(bytes: 4096)
        defer { exe.remove() }
        let proc = Process()
        proc.executableURL = exe.url
        let pipe = Pipe()
        proc.standardError = pipe
        try proc.run()
        let err = pipe.fileHandleForReading.readDataToEndOfFile()
        proc.waitUntilExit()
        XCTAssertEqual(err.count, 4096)
    }

    func testLoopbackListenerAcceptsConnections() async throws {
        let listener = try LoopbackListener()
        defer { listener.close() }
        let status = await HealthChecker().check(.tcp(port: listener.port))
        XCTAssertEqual(status, .running)
    }
}
