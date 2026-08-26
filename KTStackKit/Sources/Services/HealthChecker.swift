import Foundation

public enum HealthProbe: Sendable {
    case tcp(port: Int)

    case tcpHost(host: String, port: Int)

    case unixSocket(URL)

    case http(URL)
}

public struct HealthChecker: Sendable {
    public init() {}

    public func check(_ probe: HealthProbe, timeout: TimeInterval = 0.8) async -> ServiceStatus {
        switch probe {
        case let .tcp(port): Self.tcpConnect(host: "127.0.0.1", port: port, timeout: timeout) ? .running : .stopped
        case let .tcpHost(host, port): Self.tcpConnect(host: host, port: port, timeout: timeout) ? .running : .stopped
        case let .unixSocket(url): Self.unixConnect(path: url.path) ? .running : .stopped
        case let .http(url): await Self.httpReachable(url, timeout: timeout) ? .running : .stopped
        }
    }

    // getaddrinfo lo cả IPv4 literal, localhost và hostname; blocking nên chỉ gọi trong probe task.
    static func tcpConnect(host: String, port: Int, timeout: TimeInterval) -> Bool {
        var hints = addrinfo()
        hints.ai_family = AF_UNSPEC
        hints.ai_socktype = SOCK_STREAM
        var res: UnsafeMutablePointer<addrinfo>?
        guard getaddrinfo(host, String(port), &hints, &res) == 0 else { return false }
        defer { freeaddrinfo(res) }

        // localhost resolve cả ::1 và 127.0.0.1: thử lần lượt tới khi một địa chỉ nối được.
        var candidate = res
        while let info = candidate {
            if connectOne(info.pointee, timeout: timeout) { return true }
            candidate = info.pointee.ai_next
        }
        return false
    }

    private static func connectOne(_ info: addrinfo, timeout: TimeInterval) -> Bool {
        let fd = socket(info.ai_family, info.ai_socktype, info.ai_protocol)
        guard fd >= 0 else { return false }
        defer { close(fd) }

        let flags = fcntl(fd, F_GETFL, 0)
        _ = fcntl(fd, F_SETFL, flags | O_NONBLOCK)

        let rc = connect(fd, info.ai_addr, info.ai_addrlen)
        if rc == 0 { return true }
        if errno != EINPROGRESS { return false }

        var wfds = fd_set()
        Self.fdZero(&wfds); Self.fdSet(fd, &wfds)
        var tv = timeval(tv_sec: Int(timeout), tv_usec: __darwin_suseconds_t((timeout - floor(timeout)) * 1_000_000))
        guard select(fd + 1, nil, &wfds, nil, &tv) > 0 else { return false }

        var err: Int32 = 0
        var len = socklen_t(MemoryLayout<Int32>.size)
        getsockopt(fd, SOL_SOCKET, SO_ERROR, &err, &len)
        return err == 0
    }

    static func unixConnect(path: String) -> Bool {
        guard FileManager.default.fileExists(atPath: path) else { return false }
        let fd = socket(AF_UNIX, SOCK_STREAM, 0)
        guard fd >= 0 else { return false }
        defer { close(fd) }

        var addr = sockaddr_un()
        addr.sun_family = sa_family_t(AF_UNIX)
        let capacity = MemoryLayout.size(ofValue: addr.sun_path) // computed before the mutation
        guard path.utf8.count < capacity else { return false }
        _ = withUnsafeMutablePointer(to: &addr.sun_path) { tuplePtr in
            tuplePtr.withMemoryRebound(to: CChar.self, capacity: capacity) { dst in
                strncpy(dst, path, capacity - 1)
            }
        }
        let rc = withUnsafePointer(to: &addr) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                connect(fd, $0, socklen_t(MemoryLayout<sockaddr_un>.size))
            }
        }
        return rc == 0
    }

    static func httpReachable(_ url: URL, timeout: TimeInterval) async -> Bool {
        var req = URLRequest(url: url)
        req.httpMethod = "GET"
        req.timeoutInterval = timeout
        let cfg = URLSessionConfiguration.ephemeral
        cfg.timeoutIntervalForRequest = timeout
        let session = URLSession(configuration: cfg)
        do {
            let (_, response) = try await session.data(for: req)
            return (response as? HTTPURLResponse) != nil
        } catch {
            return false
        }
    }

    private static func fdZero(_ set: inout fd_set) {
        set.fds_bits = (
            0,
            0,
            0,
            0,
            0,
            0,
            0,
            0,
            0,
            0,
            0,
            0,
            0,
            0,
            0,
            0,
            0,
            0,
            0,
            0,
            0,
            0,
            0,
            0,
            0,
            0,
            0,
            0,
            0,
            0,
            0,
            0
        )
    }

    private static func fdSet(_ fd: Int32, _ set: inout fd_set) {
        let intOffset = Int(fd) / 32
        let bitOffset = Int(fd) % 32
        let mask = Int32(bitPattern: UInt32(1) << UInt32(bitOffset))
        withUnsafeMutablePointer(to: &set.fds_bits) {
            $0.withMemoryRebound(to: Int32.self, capacity: 32) { $0[intOffset] |= mask }
        }
    }
}
