import Foundation
import KTStackCore

public final class KTLocalIPCSocketListener: @unchecked Sendable {
    static let maxRequestBytes = 1 << 20

    private let socketPath: String
    private let dispatcher: KTIPCCommandDispatcher
    private let receiveTimeout: Int
    private let retryDelay: TimeInterval
    private let maxBindAttempts: Int
    private let lock = NSLock()
    private var serverFd: Int32 = -1
    private var isRunning = false
    private var bindAttempts = 0
    private let queue = DispatchQueue(label: "com.ktstack.ipc.listener", qos: .userInitiated)
    private let clientQueue = DispatchQueue(label: "com.ktstack.ipc.clients", qos: .userInitiated, attributes: .concurrent)

    public init(
        socketPath: String = AppSupportPaths().ipcSocket.path,
        dispatcher: KTIPCCommandDispatcher,
        receiveTimeout: Int = 5,
        retryDelay: TimeInterval = 2,
        maxBindAttempts: Int = 5
    ) {
        self.socketPath = socketPath
        self.dispatcher = dispatcher
        self.receiveTimeout = receiveTimeout
        self.retryDelay = retryDelay
        self.maxBindAttempts = maxBindAttempts
    }

    public var isListening: Bool {
        locked { isRunning && serverFd >= 0 }
    }

    public func start() {
        let shouldStart = locked { () -> Bool in
            guard !isRunning else { return false }
            isRunning = true
            bindAttempts = 0
            return true
        }
        if shouldStart { attemptBind() }
    }

    public func stop() {
        let fd = locked { () -> Int32 in
            isRunning = false
            let fd = serverFd
            serverFd = -1
            return fd
        }
        if fd >= 0 { close(fd) }
        unlink(socketPath)
    }

    private func attemptBind() {
        guard locked({ isRunning && serverFd < 0 }) else { return }
        do {
            let fd = try IPCSocketBinder.bind(path: socketPath)
            let kept = locked { () -> Bool in
                guard isRunning else { return false }
                serverFd = fd
                return true
            }
            guard kept else {
                close(fd)
                unlink(socketPath)
                return
            }
            queue.async { self.acceptLoop(fd) }
        } catch {
            let attempt = locked { () -> Int in
                bindAttempts += 1
                return bindAttempts
            }
            NSLog("KTStack: IPC socket bind failed (attempt \(attempt)/\(maxBindAttempts)): \(error.localizedDescription)")
            guard attempt < maxBindAttempts else { return }
            queue.asyncAfter(deadline: .now() + retryDelay) { [weak self] in self?.attemptBind() }
        }
    }

    private func acceptLoop(_ fd: Int32) {
        while locked({ isRunning && serverFd == fd }) {
            let client = accept(fd, nil, nil)
            if client < 0 {
                if errno == EINTR { continue }
                break
            }
            guard Self.peerIsCurrentUser(client) else {
                close(client)
                continue
            }
            let dispatcher = dispatcher
            let timeout = receiveTimeout
            clientQueue.async { Self.serve(client, dispatcher: dispatcher, timeout: timeout) }
        }
    }

    private func locked<T>(_ body: () -> T) -> T {
        lock.lock()
        defer { lock.unlock() }
        return body()
    }

    deinit {
        stop()
    }
}
