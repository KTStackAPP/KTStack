import Foundation
import KTStackCore

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
        let written = data.withUnsafeBytes { write(fd, $0.baseAddress, data.count) }
        guard written == data.count else {
            throw KTCLIError.connectionFailed("Failed to send full request payload.")
        }

        var buffer = [UInt8](repeating: 0, count: 65536)
        let bytesRead = read(fd, &buffer, buffer.count)
        guard bytesRead > 0 else {
            throw KTCLIError.malformedResponse
        }

        let respData = Data(buffer.prefix(bytesRead))
        let resp = try JSONDecoder().decode(KTIPCResponse.self, from: respData)
        if resp.success {
            return resp.result ?? ""
        } else {
            throw KTCLIError.serverError(resp.error ?? "Unknown error")
        }
    }
}
