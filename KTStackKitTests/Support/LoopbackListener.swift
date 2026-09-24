import Darwin
import Foundation

final class LoopbackListener {
    let port: Int
    private var fd: Int32

    init() throws {
        let socketFD = socket(AF_INET, SOCK_STREAM, 0)
        guard socketFD >= 0 else { throw POSIXError(.EADDRNOTAVAIL) }
        var addr = sockaddr_in()
        addr.sin_family = sa_family_t(AF_INET)
        addr.sin_addr.s_addr = inet_addr("127.0.0.1")
        addr.sin_port = 0
        let bound = withUnsafePointer(to: &addr) { ptr in
            ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                Darwin.bind(socketFD, $0, socklen_t(MemoryLayout<sockaddr_in>.size))
            }
        }
        guard bound == 0, listen(socketFD, 16) == 0 else {
            Darwin.close(socketFD)
            throw POSIXError(.EADDRINUSE)
        }
        var named = sockaddr_in()
        var len = socklen_t(MemoryLayout<sockaddr_in>.size)
        _ = withUnsafeMutablePointer(to: &named) { ptr in
            ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) { getsockname(socketFD, $0, &len) }
        }
        fd = socketFD
        port = Int(UInt16(bigEndian: named.sin_port))
    }

    func close() {
        guard fd >= 0 else { return }
        Darwin.close(fd)
        fd = -1
    }

    deinit {
        close()
    }
}
