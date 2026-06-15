import Foundation

public final class HelperConnection: @unchecked Sendable {
    private let lock = NSLock()
    private var connection: NSXPCConnection?

    public init() {}

    public func remoteProxy(_ errorHandler: @escaping (Error) -> Void) -> HelperXPCProtocol? {
        lock.lock(); defer { lock.unlock() }
        let c = connection ?? makeConnection()
        connection = c
        return c.remoteObjectProxyWithErrorHandler(errorHandler) as? HelperXPCProtocol
    }

    public func invalidate() {
        lock.lock(); defer { lock.unlock() }
        connection?.invalidate()
        connection = nil
    }

    private func makeConnection() -> NSXPCConnection {
        let c = NSXPCConnection(machServiceName: HelperIdentity.machServiceName, options: .privileged)
        c.remoteObjectInterface = NSXPCInterface(with: HelperXPCProtocol.self)
        if #available(macOS 13.0, *) {
            c.setCodeSigningRequirement(HelperIdentity.helperRequirement)
        }
        c.invalidationHandler = { [weak self] in self?.clear() }
        c.interruptionHandler = { [weak self] in self?.clear() }
        c.resume()
        return c
    }

    private func clear() {
        lock.lock(); connection = nil; lock.unlock()
    }
}
