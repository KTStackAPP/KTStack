import Foundation
import KTStackCore

public final class KTLocalIPCSocketListener: @unchecked Sendable {
    private let socketPath: String
    private let dispatcher: KTIPCCommandDispatcher
    private var serverFd: Int32 = -1
    private var isRunning = false
    private let queue = DispatchQueue(label: "com.ktstack.ipc.listener", qos: .userInitiated)

    public init(
        socketPath: String = AppSupportPaths().ipcSocket.path,
        dispatcher: KTIPCCommandDispatcher
    ) {
        self.socketPath = socketPath
        self.dispatcher = dispatcher
    }

    public func start() {
        guard !isRunning else { return }
        unlink(socketPath)

        let fd = socket(AF_UNIX, SOCK_STREAM, 0)
        guard fd >= 0 else { return }

        var addr = sockaddr_un()
        addr.sun_family = sa_family_t(AF_UNIX)
        let capacity = MemoryLayout.size(ofValue: addr.sun_path)
        guard socketPath.utf8.count < capacity else {
            close(fd)
            return
        }

        _ = withUnsafeMutablePointer(to: &addr.sun_path) { tuplePtr in
            tuplePtr.withMemoryRebound(to: CChar.self, capacity: capacity) { dst in
                strncpy(dst, socketPath, capacity - 1)
            }
        }

        let bindResult = withUnsafePointer(to: &addr) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                bind(fd, $0, socklen_t(MemoryLayout<sockaddr_un>.size))
            }
        }
        guard bindResult == 0 else {
            close(fd)
            return
        }

        chmod(socketPath, 0o600)
        guard listen(fd, 10) == 0 else {
            close(fd)
            return
        }

        serverFd = fd
        isRunning = true

        queue.async { [weak self] in
            self?.acceptLoop()
        }
    }

    public func stop() {
        isRunning = false
        if serverFd >= 0 {
            close(serverFd)
            serverFd = -1
        }
        unlink(socketPath)
    }

    private func acceptLoop() {
        while isRunning && serverFd >= 0 {
            let clientFd = accept(serverFd, nil, nil)
            guard clientFd >= 0 else { break }

            Task.detached { [dispatcher = self.dispatcher] in
                await Self.handleClient(clientFd, dispatcher: dispatcher)
            }
        }
    }

    private static func handleClient(_ fd: Int32, dispatcher: KTIPCCommandDispatcher) async {
        defer { close(fd) }
        var reqData = Data()
        var buffer = [UInt8](repeating: 0, count: 4096)
        while true {
            let bytesRead = read(fd, &buffer, buffer.count)
            if bytesRead < 0 {
                if errno == EINTR { continue }
                return
            }
            if bytesRead == 0 { break }
            reqData.append(buffer, count: bytesRead)
            if (try? JSONDecoder().decode(KTIPCRequest.self, from: reqData)) != nil {
                break
            }
        }
        guard !reqData.isEmpty else { return }

        guard let request = try? JSONDecoder().decode(KTIPCRequest.self, from: reqData) else {
            let errResponse = KTIPCResponse.fail("Malformed JSON request")
            if let errData = try? JSONEncoder().encode(errResponse) {
                writeAll(fd, data: errData)
            }
            return
        }

        let response = await dispatcher.dispatch(request)
        if let respData = try? JSONEncoder().encode(response) {
            writeAll(fd, data: respData)
        }
    }

    private static func writeAll(_ fd: Int32, data: Data) {
        data.withUnsafeBytes { rawBuffer in
            guard let base = rawBuffer.baseAddress else { return }
            var remaining = data.count
            var offset = 0
            while remaining > 0 {
                let written = write(fd, base.advanced(by: offset), remaining)
                if written <= 0 {
                    if errno == EINTR { continue }
                    break
                }
                offset += written
                remaining -= written
            }
        }
    }

    deinit {
        stop()
    }
}
