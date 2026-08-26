import Darwin
import XCTest
@testable import KTStackKit

final class UpstreamProbeTests: XCTestCase {
    private let probe = UpstreamProbe()

    func testProbeStoppedWhenNothingListens() async {
        let state = await probe.probe(host: "127.0.0.1", port: 59_999)
        XCTAssertEqual(state, .stopped)
    }

    func testProbeRunningWhenListenerAnswers() async throws {
        let (fd, port) = try Self.openListener()
        defer { close(fd) }
        let state = await probe.probe(host: "127.0.0.1", port: port)
        XCTAssertEqual(state, .running)
    }

    func testProbeResolvesLocalhostHostname() async throws {
        let (fd, port) = try Self.openListener()
        defer { close(fd) }
        let state = await probe.probe(host: "localhost", port: port)
        XCTAssertEqual(state, .running)
    }

    func testBadgeAndServiceStatusMapping() {
        XCTAssertEqual(UpstreamProbe.State.running.badgeLabel, "Running")
        XCTAssertEqual(UpstreamProbe.State.stopped.badgeLabel, "Stopped")
        XCTAssertTrue(UpstreamProbe.State.running.isHealthy)
        XCTAssertFalse(UpstreamProbe.State.stopped.isHealthy)
        XCTAssertEqual(UpstreamProbe.State.running.serviceStatus, .running)
        XCTAssertEqual(UpstreamProbe.State.stopped.serviceStatus, .stopped)
    }

    private static func openListener() throws -> (Int32, Int) {
        let fd = socket(AF_INET, SOCK_STREAM, 0)
        guard fd >= 0 else { throw error("socket") }
        var yes: Int32 = 1
        setsockopt(fd, SOL_SOCKET, SO_REUSEADDR, &yes, socklen_t(MemoryLayout<Int32>.size))
        var addr = sockaddr_in()
        addr.sin_family = sa_family_t(AF_INET)
        addr.sin_addr.s_addr = inet_addr("127.0.0.1")
        addr.sin_port = 0
        let bound = withUnsafePointer(to: &addr) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                Darwin.bind(fd, $0, socklen_t(MemoryLayout<sockaddr_in>.size))
            }
        }
        guard bound == 0, listen(fd, 1) == 0 else { close(fd); throw error("bind/listen") }
        var named = sockaddr_in()
        var len = socklen_t(MemoryLayout<sockaddr_in>.size)
        let got = withUnsafeMutablePointer(to: &named) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                getsockname(fd, $0, &len)
            }
        }
        guard got == 0 else { close(fd); throw error("getsockname") }
        return (fd, Int(UInt16(bigEndian: named.sin_port)))
    }

    private static func error(_ message: String) -> NSError {
        NSError(domain: "UpstreamProbeTests", code: 1, userInfo: [NSLocalizedDescriptionKey: message])
    }
}
