import Darwin
import Foundation

/// Tiny loopback HTTP server for proxy integration: answers 200 with a fixed body that echoes the
/// X-Forwarded-Proto header nginx forwarded, so the test can assert the front proxied the request.
final class LoopbackUpstream {
    let port: Int
    private let listenFD: Int32
    private var running = true
    private let queue = DispatchQueue(label: "ktstack.loopback-upstream")

    init() throws {
        let fd = socket(AF_INET, SOCK_STREAM, 0)
        guard fd >= 0 else { throw POSIXError(.EADDRNOTAVAIL) }
        var yes: Int32 = 1
        setsockopt(fd, SOL_SOCKET, SO_REUSEADDR, &yes, socklen_t(MemoryLayout<Int32>.size))
        var addr = sockaddr_in()
        addr.sin_family = sa_family_t(AF_INET)
        addr.sin_addr.s_addr = inet_addr("127.0.0.1")
        addr.sin_port = 0
        let bound = withUnsafePointer(to: &addr) { ptr in
            ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                Darwin.bind(fd, $0, socklen_t(MemoryLayout<sockaddr_in>.size))
            }
        }
        guard bound == 0, listen(fd, 8) == 0 else { close(fd); throw POSIXError(.EADDRINUSE) }
        var named = sockaddr_in()
        var len = socklen_t(MemoryLayout<sockaddr_in>.size)
        _ = withUnsafeMutablePointer(to: &named) { ptr in
            ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) { getsockname(fd, $0, &len) }
        }
        listenFD = fd
        port = Int(UInt16(bigEndian: named.sin_port))
        start()
    }

    private func start() {
        queue.async { [listenFD] in
            while self.running {
                let clientFD = accept(listenFD, nil, nil)
                if clientFD < 0 { break }
                Self.handle(clientFD)
            }
        }
    }

    private static func handle(_ fd: Int32) {
        defer { close(fd) }
        var buffer = [UInt8](repeating: 0, count: 4096)
        let count = read(fd, &buffer, buffer.count)
        let request = count > 0 ? String(decoding: buffer[0 ..< count], as: UTF8.self) : ""
        let proto = header("X-Forwarded-Proto", in: request) ?? "none"
        let body = "upstream-ok proto=\(proto)"
        let response = "HTTP/1.1 200 OK\r\nContent-Type: text/plain\r\nContent-Length: \(body.utf8.count)\r\nConnection: close\r\n\r\n\(body)"
        let bytes = Array(response.utf8)
        _ = bytes.withUnsafeBytes { write(fd, $0.baseAddress, $0.count) }
    }

    private static func header(_ name: String, in request: String) -> String? {
        for line in request.split(separator: "\r\n") {
            let parts = line.split(separator: ":", maxSplits: 1)
            if parts.count == 2, parts[0].lowercased() == name.lowercased() {
                return parts[1].trimmingCharacters(in: .whitespaces)
            }
        }
        return nil
    }

    func stop() {
        running = false
        close(listenFD)
    }
}
