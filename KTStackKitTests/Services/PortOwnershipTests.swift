import Darwin
import KTStackCore
import XCTest
@testable import KTStackKit

final class PortOwnershipTests: XCTestCase {
    private let label = "com.ktstack.ownership-test"
    private var root: URL!
    private var paths: AppSupportPaths!

    override func setUpWithError() throws {
        root = FileManager.default.temporaryDirectory.appendingPathComponent("kt-owner-\(UUID().uuidString)")
        paths = AppSupportPaths(root: root)
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

    func testIPv6LoopbackListenerIsInUse() throws {
        let fd = socket(AF_INET6, SOCK_STREAM, 0)
        XCTAssertGreaterThanOrEqual(fd, 0)
        defer { close(fd) }
        var addr = sockaddr_in6()
        addr.sin6_family = sa_family_t(AF_INET6)
        addr.sin6_addr = in6addr_loopback
        let bound = withUnsafePointer(to: &addr) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) { Darwin.bind(fd, $0, socklen_t(MemoryLayout<sockaddr_in6>.size)) }
        }
        XCTAssertEqual(bound, 0)
        XCTAssertEqual(listen(fd, 1), 0)
        var named = sockaddr_in6()
        var len = socklen_t(MemoryLayout<sockaddr_in6>.size)
        _ = withUnsafeMutablePointer(to: &named) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) { getsockname(fd, $0, &len) }
        }
        let port = Int(UInt16(bigEndian: named.sin6_port))
        guard case .inUse = PortPreflight().check(port: port) else {
            return XCTFail("a ::1-only listener must be reported in use")
        }
    }

    func testStartSucceedsWhenTheJobOwnsThePort() async throws {
        let listener = try LoopbackListener()
        defer { listener.close() }
        let agents = FakeLaunchAgentManager(paths: paths)
        agents.setJobPID(getpid(), for: label)
        try await runner(agents, port: listener.port).restart(spec: spec())
        XCTAssertFalse(agents.calls.contains(.bootout(label)))
    }

    func testStartFailsAndBootsOutWhenAnotherProcessAnswers() async throws {
        let listener = try LoopbackListener()
        defer { listener.close() }
        let agents = FakeLaunchAgentManager(paths: paths)
        agents.setJobPID(pid_t(Int32.max - 7), for: label)
        do {
            try await runner(agents, port: listener.port).restart(spec: spec())
            XCTFail("a port answered by a foreign process must fail the start")
        } catch {
            XCTAssertTrue(error.localizedDescription.contains("port \(listener.port)"), error.localizedDescription)
        }
        XCTAssertTrue(agents.calls.contains(.bootout(label)))
    }

    func testProbeReportsStoppedWhenTheJobIsNotLoaded() async throws {
        let listener = try LoopbackListener()
        defer { listener.close() }
        let agents = FakeLaunchAgentManager(paths: paths)
        let status = await runner(agents, port: listener.port).probe()
        XCTAssertEqual(status, .stopped)
        agents.markLoaded(label)
        let loaded = await runner(agents, port: listener.port).probe()
        XCTAssertEqual(loaded, .running)
    }

    func testParsesPIDFromLaunchctlPrint() {
        let output = "gui/501/com.ktstack.redis = {\n\tactive count = 1\n\tpid = 4242\n\tstate = running\n}"
        XCTAssertEqual(LaunchAgentManager.parsePID(from: output), 4242)
        XCTAssertNil(LaunchAgentManager.parsePID(from: "state = not running"))
    }
}
