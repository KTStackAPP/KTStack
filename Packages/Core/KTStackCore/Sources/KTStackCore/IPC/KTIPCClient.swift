import Foundation

public enum KTCLIError: LocalizedError, Sendable {
    case connectionFailed(String)
    case serverError(String)
    case malformedResponse

    public var errorDescription: String? {
        switch self {
        case let .connectionFailed(msg):
            return "Cannot connect to KTStack app at \(msg). Is KTStack running?"
        case let .serverError(msg):
            return "KTStack error: \(msg)"
        case .malformedResponse:
            return "Received invalid response from KTStack."
        }
    }
}

public struct KTIPCClient: Sendable {
    public let socketPath: String

    public init(socketPath: String = AppSupportPaths().ipcSocket.path) {
        self.socketPath = socketPath
    }

    public func call(method: String, params: [String: String]? = nil) throws -> String {
        let fd = socket(AF_UNIX, SOCK_STREAM, 0)
        guard fd >= 0 else {
            throw KTCLIError.connectionFailed(socketPath)
        }
        defer { close(fd) }

        var addr = sockaddr_un()
        addr.sun_family = sa_family_t(AF_UNIX)
        let capacity = MemoryLayout.size(ofValue: addr.sun_path)
        guard socketPath.utf8.count < capacity else {
            throw KTCLIError.connectionFailed("Path too long: \(socketPath)")
        }

        _ = withUnsafeMutablePointer(to: &addr.sun_path) { tuplePtr in
            tuplePtr.withMemoryRebound(to: CChar.self, capacity: capacity) { dst in
                strncpy(dst, socketPath, capacity - 1)
            }
        }

        let rc = withUnsafePointer(to: &addr) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                connect(fd, $0, socklen_t(MemoryLayout<sockaddr_un>.size))
            }
        }
        guard rc == 0 else {
            throw KTCLIError.connectionFailed(socketPath)
        }

        let req = KTIPCRequest(id: UUID().uuidString, method: method, params: params)
        let data = try JSONEncoder().encode(req)
        try data.withUnsafeBytes { rawBuffer in
            guard let base = rawBuffer.baseAddress else { return }
            var remaining = data.count
            var offset = 0
            while remaining > 0 {
                let written = write(fd, base.advanced(by: offset), remaining)
                if written <= 0 {
                    if errno == EINTR { continue }
                    throw KTCLIError.connectionFailed("Failed to send full request payload.")
                }
                offset += written
                remaining -= written
            }
        }
        _ = shutdown(fd, SHUT_WR)

        var fullData = Data()
        var buffer = [UInt8](repeating: 0, count: 16384)
        while true {
            let bytesRead = read(fd, &buffer, buffer.count)
            if bytesRead < 0 {
                if errno == EINTR { continue }
                throw KTCLIError.malformedResponse
            }
            if bytesRead == 0 { break }
            fullData.append(buffer, count: bytesRead)
        }

        guard !fullData.isEmpty else {
            throw KTCLIError.malformedResponse
        }

        let resp = try JSONDecoder().decode(KTIPCResponse.self, from: fullData)
        if resp.success {
            return resp.result ?? ""
        } else {
            throw KTCLIError.serverError(resp.error ?? "Unknown error")
        }
    }
}
