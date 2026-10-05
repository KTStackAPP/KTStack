import Foundation

public final class LoopbackRequest: @unchecked Sendable {
    static let maxHeaderBytes = 16 * 1024

    public let method: String
    public let target: String
    private let connection: Int32
    private let lock = NSLock()
    private var open = true

    init?(connection: Int32) {
        var timeout = timeval(tv_sec: 5, tv_usec: 0)
        setsockopt(connection, SOL_SOCKET, SO_RCVTIMEO, &timeout, socklen_t(MemoryLayout<timeval>.size))
        var noSignal: Int32 = 1
        setsockopt(connection, SOL_SOCKET, SO_NOSIGPIPE, &noSignal, socklen_t(MemoryLayout<Int32>.size))
        guard let head = Self.readHead(connection), let line = head.components(separatedBy: "\r\n").first else {
            close(connection)
            return nil
        }
        let parts = line.split(separator: " ")
        guard parts.count >= 2 else {
            close(connection)
            return nil
        }
        method = String(parts[0])
        target = String(parts[1])
        self.connection = connection
    }

    deinit {
        finish()
    }

    public var path: String {
        String(target.split(separator: "?", maxSplits: 1).first ?? "")
    }

    public var queryItems: [String: String] {
        let items = URLComponents(string: "http://127.0.0.1\(target)")?.queryItems ?? []
        return Dictionary(items.map { ($0.name, $0.value ?? "") }, uniquingKeysWith: { first, _ in first })
    }

    public func respond(status: Int, contentType: String = "text/html; charset=utf-8", body: String) {
        let payload = Data(body.utf8)
        let reason = status == 200 ? "OK" : status == 404 ? "Not Found" : "Bad Request"
        let head = "HTTP/1.1 \(status) \(reason)\r\nContent-Type: \(contentType)\r\nContent-Length: \(payload.count)\r\n"
            + "Cache-Control: no-store\r\nReferrer-Policy: no-referrer\r\nConnection: close\r\n\r\n"
        write(Data(head.utf8) + payload)
        finish()
    }

    private func write(_ data: Data) {
        data.withUnsafeBytes { buffer in
            var sent = 0
            while sent < buffer.count {
                let result = send(connection, buffer.baseAddress! + sent, buffer.count - sent, 0)
                guard result > 0 else { return }
                sent += result
            }
        }
    }

    private func finish() {
        lock.lock()
        defer { lock.unlock() }
        guard open else { return }
        open = false
        close(connection)
    }

    private static func readHead(_ connection: Int32) -> String? {
        var data = Data()
        var buffer = [UInt8](repeating: 0, count: 4096)
        let terminator = Data("\r\n\r\n".utf8)
        while data.count < maxHeaderBytes {
            let count = recv(connection, &buffer, buffer.count, 0)
            guard count > 0 else { break }
            data.append(contentsOf: buffer[0..<count])
            if data.range(of: terminator) != nil { break }
        }
        return data.isEmpty ? nil : String(data: data, encoding: .utf8)
    }
}
