import Darwin
import Foundation
import KTStackCore
import XCTest
@testable import KTStackKit

final class IPCListenerHardeningTests: XCTestCase {
    private var root: String!
    private var listener: KTLocalIPCSocketListener?

    override func setUp() {
        super.setUp()
        root = "/tmp/kt-ipc-\(UUID().uuidString.prefix(8))"
    }

    override func tearDown() {
        listener?.stop()
        try? FileManager.default.removeItem(atPath: root)
        super.tearDown()
    }

    private func startListener(at path: String, timeout: Int = 5) -> KTLocalIPCSocketListener {
        let dispatcher = KTIPCCommandDispatcher(serverProvider: { nil }, servicesProvider: { nil })
        let made = KTLocalIPCSocketListener(
            socketPath: path, dispatcher: dispatcher, receiveTimeout: timeout, retryDelay: 0.1
        )
        made.start()
        listener = made
        return made
    }

    private func connectRaw(_ path: String) throws -> Int32 {
        let fd = socket(AF_UNIX, SOCK_STREAM, 0)
        var on: Int32 = 1
        setsockopt(fd, SOL_SOCKET, SO_NOSIGPIPE, &on, socklen_t(MemoryLayout<Int32>.size))
        var wait = timeval(tv_sec: 10, tv_usec: 0)
        setsockopt(fd, SOL_SOCKET, SO_RCVTIMEO, &wait, socklen_t(MemoryLayout<timeval>.size))
        var addr = sockaddr_un()
        addr.sun_family = sa_family_t(AF_UNIX)
        let capacity = MemoryLayout.size(ofValue: addr.sun_path)
        _ = withUnsafeMutablePointer(to: &addr.sun_path) { ptr in
            ptr.withMemoryRebound(to: CChar.self, capacity: capacity) { strncpy($0, path, capacity - 1) }
        }
        let rc = withUnsafePointer(to: &addr) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                connect(fd, $0, socklen_t(MemoryLayout<sockaddr_un>.size))
            }
        }
        guard rc == 0 else {
            close(fd)
            throw KTCLIError.connectionFailed(path)
        }
        return fd
    }

    private func readAll(_ fd: Int32) -> Data {
        var data = Data()
        var buffer = [UInt8](repeating: 0, count: 4096)
        while true {
            let count = read(fd, &buffer, buffer.count)
            if count <= 0 { break }
            data.append(buffer, count: count)
        }
        return data
    }

    func testBindsWhenTheRunDirectoryDoesNotExistYet() throws {
        let path = "\(root!)/run/ktstack.sock"
        _ = startListener(at: path)
        XCTAssertEqual(try KTIPCClient(socketPath: path).call(method: "ping"), "pong")
        let attributes = try FileManager.default.attributesOfItem(atPath: "\(root!)/run")
        XCTAssertEqual((attributes[.posixPermissions] as? NSNumber)?.intValue, 0o700)
    }

    func testOversizedRequestIsRejected() throws {
        let path = "\(root!)/big.sock"
        _ = startListener(at: path)
        let fd = try connectRaw(path)
        defer { close(fd) }
        let chunk = [UInt8](repeating: UInt8(ascii: "a"), count: 64 * 1024)
        for _ in 0..<20 {
            if chunk.withUnsafeBytes({ write(fd, $0.baseAddress, chunk.count) }) <= 0 { break }
        }
        shutdown(fd, SHUT_WR)
        let response = try JSONDecoder().decode(KTIPCResponse.self, from: readAll(fd))
        XCTAssertFalse(response.success)
        XCTAssertTrue(response.error?.contains("exceeds") == true, response.error ?? "")
    }

    func testSilentClientIsDisconnectedAfterTheReceiveTimeout() throws {
        let path = "\(root!)/idle.sock"
        _ = startListener(at: path, timeout: 1)
        let fd = try connectRaw(path)
        defer { close(fd) }
        let started = Date()
        var byte: UInt8 = 0
        let count = read(fd, &byte, 1)
        XCTAssertEqual(count, 0)
        XCTAssertLessThan(Date().timeIntervalSince(started), 5)
    }

    func testStopThenStartServesAgain() throws {
        let path = "\(root!)/restart.sock"
        let made = startListener(at: path)
        made.stop()
        made.stop()
        XCTAssertFalse(made.isListening)
        made.start()
        XCTAssertTrue(made.isListening)
        XCTAssertEqual(try KTIPCClient(socketPath: path).call(method: "ping"), "pong")
    }
}
