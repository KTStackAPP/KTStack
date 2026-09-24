import Combine
import Darwin
import XCTest
@testable import KTDumpsPlugin

final class DumpServerTests: XCTestCase {
    private var server: DumpServer!
    private var sockets: [Int32] = []

    override func tearDown() {
        sockets.forEach { close($0) }
        server?.stop()
    }

    private func connect(_ port: UInt16) throws -> Int32 {
        let fd = socket(AF_INET, SOCK_STREAM, 0)
        var yes: Int32 = 1
        setsockopt(fd, SOL_SOCKET, SO_NOSIGPIPE, &yes, socklen_t(MemoryLayout<Int32>.size))
        var addr = sockaddr_in()
        addr.sin_family = sa_family_t(AF_INET)
        addr.sin_port = port.bigEndian
        addr.sin_addr.s_addr = inet_addr("127.0.0.1")
        let rc = withUnsafePointer(to: &addr) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                Darwin.connect(fd, $0, socklen_t(MemoryLayout<sockaddr_in>.size))
            }
        }
        guard rc == 0 else { close(fd); throw POSIXError(.ECONNREFUSED) }
        sockets.append(fd)
        return fd
    }

    private func send(_ fd: Int32, _ text: String) -> Int {
        Array(text.utf8).withUnsafeBytes { write(fd, $0.baseAddress, $0.count) }
    }

    private func isClosedByServer(_ fd: Int32, within seconds: TimeInterval = 3) -> Bool {
        var timeout = timeval(tv_sec: Int(seconds), tv_usec: 0)
        setsockopt(fd, SOL_SOCKET, SO_RCVTIMEO, &timeout, socklen_t(MemoryLayout<timeval>.size))
        var byte: UInt8 = 0
        return read(fd, &byte, 1) == 0
    }

    private func waitFor(_ condition: () -> Bool) {
        for _ in 0..<300 where !condition() { usleep(10000) }
    }

    func testStartReturnsTheBoundPortAfterReady() async throws {
        server = DumpServer(limits: DumpServerLimits())
        let port = try await server.start(preferred: 0)
        XCTAssertGreaterThan(port, 0)
        XCTAssertEqual(server.port, port)
        _ = try connect(port)
    }

    func testDeliversEventsLineByLine() async throws {
        server = DumpServer(limits: DumpServerLimits())
        var received: [DumpEvent] = []
        let sink = server.eventsPublisher.sink { received.append($0) }
        defer { sink.cancel() }
        let fd = try connect(try await server.start(preferred: 0))
        _ = send(fd, #"{"timestamp":1,"file":"a.php","line":3,"value":{"type":"int","value":7}}"# + "\n")
        waitFor { received.count == 1 }
        XCTAssertEqual(received.count, 1)
    }

    func testOversizedConnectionIsDropped() async throws {
        server = DumpServer(limits: DumpServerLimits(maxConnectionBytes: 1024, maxConnections: 4, idleTimeout: 30))
        let fd = try connect(try await server.start(preferred: 0))
        _ = send(fd, String(repeating: "x", count: 4096))
        XCTAssertTrue(isClosedByServer(fd))
    }

    func testConnectionsBeyondTheCapAreRefused() async throws {
        server = DumpServer(limits: DumpServerLimits(maxConnectionBytes: 1024, maxConnections: 2, idleTimeout: 30))
        let port = try await server.start(preferred: 0)
        _ = try connect(port)
        _ = try connect(port)
        waitFor { server.connectionCount == 2 }
        let extra = try connect(port)
        XCTAssertTrue(isClosedByServer(extra))
        XCTAssertEqual(server.connectionCount, 2)
    }

    func testIdleConnectionIsClosed() async throws {
        server = DumpServer(limits: DumpServerLimits(maxConnectionBytes: 1024, maxConnections: 4, idleTimeout: 0.2))
        let fd = try connect(try await server.start(preferred: 0))
        XCTAssertTrue(isClosedByServer(fd))
    }

    func testStopClosesOpenConnections() async throws {
        server = DumpServer(limits: DumpServerLimits())
        let fd = try connect(try await server.start(preferred: 0))
        waitFor { server.connectionCount == 1 }
        server.stop()
        XCTAssertTrue(isClosedByServer(fd))
        XCTAssertEqual(server.connectionCount, 0)
    }
}
