import Foundation
import XCTest
import KTStackCore
@testable import KTStackKit

final class IPCSocketTests: XCTestCase {
    private var tempDir: URL!
    private var socketPath: String!
    private var listener: KTLocalIPCSocketListener!
    private var dispatcher: KTIPCCommandDispatcher!

    override func setUp() {
        super.setUp()
        tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        socketPath = tempDir.appendingPathComponent("test.sock").path

        dispatcher = KTIPCCommandDispatcher(
            serverProvider: { nil },
            servicesProvider: { nil }
        )
        listener = KTLocalIPCSocketListener(socketPath: socketPath, dispatcher: dispatcher)
        listener.start()
    }

    override func tearDown() {
        listener.stop()
        try? FileManager.default.removeItem(at: tempDir)
        super.tearDown()
    }

    func testPingReturnsPong() async throws {
        let fd = socket(AF_UNIX, SOCK_STREAM, 0)
        XCTAssertGreaterThanOrEqual(fd, 0)
        defer { close(fd) }

        var addr = sockaddr_un()
        addr.sun_family = sa_family_t(AF_UNIX)
        let capacity = MemoryLayout.size(ofValue: addr.sun_path)
        _ = withUnsafeMutablePointer(to: &addr.sun_path) { tuplePtr in
            tuplePtr.withMemoryRebound(to: CChar.self, capacity: capacity) { dst in
                strncpy(dst, socketPath, capacity - 1)
            }
        }

        var connected = false
        for _ in 0..<10 {
            let rc = withUnsafePointer(to: &addr) {
                $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                    connect(fd, $0, socklen_t(MemoryLayout<sockaddr_un>.size))
                }
            }
            if rc == 0 {
                connected = true
                break
            }
            try await Task.sleep(nanoseconds: 20_000_000)
        }
        XCTAssertTrue(connected)

        let req = KTIPCRequest(id: "1", method: "ping")
        let reqData = try JSONEncoder().encode(req)
        _ = reqData.withUnsafeBytes { write(fd, $0.baseAddress, reqData.count) }

        var buffer = [UInt8](repeating: 0, count: 4096)
        let bytesRead = read(fd, &buffer, buffer.count)
        XCTAssertGreaterThan(bytesRead, 0)

        let respData = Data(buffer.prefix(bytesRead))
        let resp = try JSONDecoder().decode(KTIPCResponse.self, from: respData)
        XCTAssertEqual(resp.id, "1")
        XCTAssertTrue(resp.success)
        XCTAssertEqual(resp.result, "pong")
    }

    func testUnknownMethodReturnsError() async throws {
        let fd = socket(AF_UNIX, SOCK_STREAM, 0)
        XCTAssertGreaterThanOrEqual(fd, 0)
        defer { close(fd) }

        var addr = sockaddr_un()
        addr.sun_family = sa_family_t(AF_UNIX)
        let capacity = MemoryLayout.size(ofValue: addr.sun_path)
        _ = withUnsafeMutablePointer(to: &addr.sun_path) { tuplePtr in
            tuplePtr.withMemoryRebound(to: CChar.self, capacity: capacity) { dst in
                strncpy(dst, socketPath, capacity - 1)
            }
        }

        var connected = false
        for _ in 0..<10 {
            let rc = withUnsafePointer(to: &addr) {
                $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                    connect(fd, $0, socklen_t(MemoryLayout<sockaddr_un>.size))
                }
            }
            if rc == 0 {
                connected = true
                break
            }
            try await Task.sleep(nanoseconds: 20_000_000)
        }
        XCTAssertTrue(connected)

        let req = KTIPCRequest(id: "2", method: "invalid.method")
        let reqData = try JSONEncoder().encode(req)
        _ = reqData.withUnsafeBytes { write(fd, $0.baseAddress, reqData.count) }

        var buffer = [UInt8](repeating: 0, count: 4096)
        let bytesRead = read(fd, &buffer, buffer.count)
        XCTAssertGreaterThan(bytesRead, 0)

        let respData = Data(buffer.prefix(bytesRead))
        let resp = try JSONDecoder().decode(KTIPCResponse.self, from: respData)
        XCTAssertEqual(resp.id, "2")
        XCTAssertFalse(resp.success)
        XCTAssertNotNil(resp.error)
    }
}
