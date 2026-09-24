import Darwin
import Foundation
import KTStackCore

final class FakeIPCServer: @unchecked Sendable {
    let socketPath: String
    private let fd: Int32
    private let lock = NSLock()
    private var _requests: [KTIPCRequest] = []
    private let reply: @Sendable (KTIPCRequest) -> KTIPCResponse

    var requests: [KTIPCRequest] { lock.withLock { _requests } }

    init(reply: @escaping @Sendable (KTIPCRequest) -> KTIPCResponse) throws {
        self.reply = reply
        let path = "/tmp/kt-\(UUID().uuidString.prefix(8)).sock"
        unlink(path)
        let listener = socket(AF_UNIX, SOCK_STREAM, 0)
        guard listener >= 0 else { throw POSIXError(.EIO) }
        var addr = sockaddr_un()
        addr.sun_family = sa_family_t(AF_UNIX)
        let capacity = MemoryLayout.size(ofValue: addr.sun_path)
        _ = withUnsafeMutablePointer(to: &addr.sun_path) { ptr in
            ptr.withMemoryRebound(to: CChar.self, capacity: capacity) { strncpy($0, path, capacity - 1) }
        }
        let bound = withUnsafePointer(to: &addr) { ptr in
            ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                bind(listener, $0, socklen_t(MemoryLayout<sockaddr_un>.size))
            }
        }
        guard bound == 0, listen(listener, 8) == 0 else {
            close(listener)
            throw POSIXError(.EADDRINUSE)
        }
        socketPath = path
        fd = listener
        DispatchQueue.global().async { [self] in serve() }
    }

    var client: KTIPCClient {
        KTIPCClient(socketPath: socketPath)
    }

    func stop() {
        shutdown(fd, SHUT_RDWR)
        close(fd)
        unlink(socketPath)
    }

    private func serve() {
        while true {
            let conn = accept(fd, nil, nil)
            guard conn >= 0 else { return }
            handle(conn)
        }
    }

    private func handle(_ conn: Int32) {
        defer { close(conn) }
        var data = Data()
        var buffer = [UInt8](repeating: 0, count: 4096)
        while true {
            let count = read(conn, &buffer, buffer.count)
            if count <= 0 { break }
            data.append(buffer, count: count)
        }
        guard let request = try? JSONDecoder().decode(KTIPCRequest.self, from: data) else { return }
        lock.withLock { _requests.append(request) }
        guard let out = try? JSONEncoder().encode(reply(request)) else { return }
        _ = out.withUnsafeBytes { write(conn, $0.baseAddress, $0.count) }
    }
}
