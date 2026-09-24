import Darwin
import Foundation

enum IPCSocketBinder {
    struct BindError: LocalizedError {
        let step: String
        let code: Int32

        var errorDescription: String? {
            "\(step) failed: \(String(cString: strerror(code)))"
        }
    }

    static func bind(path: String) throws -> Int32 {
        let directory = (path as NSString).deletingLastPathComponent
        try FileManager.default.createDirectory(
            atPath: directory, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700]
        )
        unlink(path)
        let fd = socket(AF_UNIX, SOCK_STREAM, 0)
        guard fd >= 0 else { throw BindError(step: "socket", code: errno) }

        var addr = sockaddr_un()
        addr.sun_family = sa_family_t(AF_UNIX)
        let capacity = MemoryLayout.size(ofValue: addr.sun_path)
        guard path.utf8.count < capacity else {
            close(fd)
            throw BindError(step: "socket path", code: ENAMETOOLONG)
        }
        _ = withUnsafeMutablePointer(to: &addr.sun_path) { tuplePtr in
            tuplePtr.withMemoryRebound(to: CChar.self, capacity: capacity) { dst in
                strncpy(dst, path, capacity - 1)
            }
        }
        let bound = withUnsafePointer(to: &addr) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                Darwin.bind(fd, $0, socklen_t(MemoryLayout<sockaddr_un>.size))
            }
        }
        guard bound == 0 else {
            let code = errno
            close(fd)
            throw BindError(step: "bind", code: code)
        }
        chmod(path, 0o600)
        guard listen(fd, 16) == 0 else {
            let code = errno
            close(fd)
            unlink(path)
            throw BindError(step: "listen", code: code)
        }
        return fd
    }
}
