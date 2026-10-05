import Foundation

public final class LoopbackHTTPServer: @unchecked Sendable {
    public let port: UInt16
    private let listener: Int32
    private let lock = NSLock()
    private var stopped = false

    public init(port: UInt16 = 0) throws {
        let descriptor = socket(AF_INET, Int32(SOCK_STREAM), 0)
        guard descriptor >= 0 else { throw Self.failure("socket") }
        var reuse: Int32 = 1
        setsockopt(descriptor, SOL_SOCKET, SO_REUSEADDR, &reuse, socklen_t(MemoryLayout<Int32>.size))
        var address = sockaddr_in()
        address.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
        address.sin_family = sa_family_t(AF_INET)
        address.sin_port = port.bigEndian
        address.sin_addr.s_addr = inet_addr("127.0.0.1")
        let bound = withUnsafePointer(to: &address) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) { bind(descriptor, $0, socklen_t(MemoryLayout<sockaddr_in>.size)) }
        }
        guard bound == 0, listen(descriptor, 8) == 0 else {
            let error = Self.failure(port == 0 ? "bind" : "port \(port) is busy")
            close(descriptor)
            throw error
        }
        var actual = sockaddr_in()
        var length = socklen_t(MemoryLayout<sockaddr_in>.size)
        _ = withUnsafeMutablePointer(to: &actual) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) { getsockname(descriptor, $0, &length) }
        }
        listener = descriptor
        self.port = UInt16(bigEndian: actual.sin_port)
    }

    deinit {
        stop()
    }

    public func stop() {
        let shouldClose: Bool = {
            lock.lock()
            defer { lock.unlock() }
            let first = !stopped
            stopped = true
            return first
        }()
        if shouldClose { close(listener) }
    }

    var isStopped: Bool {
        lock.lock()
        defer { lock.unlock() }
        return stopped
    }

    public func nextRequest(timeout: TimeInterval) async throws -> LoopbackRequest {
        let deadline = Date().addingTimeInterval(timeout)
        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                Thread.detachNewThread { [self] in
                    continuation.resume(with: Result { try self.waitForRequest(until: deadline) })
                }
            }
        } onCancel: {
            stop()
        }
    }

    private func waitForRequest(until deadline: Date) throws -> LoopbackRequest {
        while true {
            if isStopped { throw CancellationError() }
            guard Date() < deadline else { throw GoogleAuthError.listenerFailed("timed out waiting for the browser.") }
            var poller = pollfd(fd: listener, events: Int16(POLLIN), revents: 0)
            guard poll(&poller, 1, 200) > 0, !isStopped else { continue }
            let connection = accept(listener, nil, nil)
            guard connection >= 0 else { continue }
            if let request = LoopbackRequest(connection: connection) { return request }
        }
    }

    static func failure(_ step: String) -> GoogleAuthError {
        .listenerFailed("\(step): \(String(cString: strerror(errno)))")
    }
}
