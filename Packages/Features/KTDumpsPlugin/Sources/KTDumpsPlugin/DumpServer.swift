import Combine
import Foundation
import Network

public final class DumpServer: @unchecked Sendable {
    public static let preferredPort: UInt16 = 9912

    private let queue = DispatchQueue(label: "com.ktstack.dumpserver", qos: .utility)
    private let subject = PassthroughSubject<DumpEvent, Never>()
    private let limits: DumpServerLimits
    private var listener: NWListener?
    private var connections: [ObjectIdentifier: DumpConnection] = [:]
    private var boundPort: UInt16 = 0

    public var eventsPublisher: AnyPublisher<DumpEvent, Never> {
        subject.eraseToAnyPublisher()
    }

    public var port: UInt16 {
        queue.sync { boundPort }
    }

    var connectionCount: Int {
        queue.sync { connections.count }
    }

    public convenience init() {
        self.init(limits: DumpServerLimits())
    }

    init(limits: DumpServerLimits) {
        self.limits = limits
    }

    @discardableResult
    public func start(preferred: UInt16 = DumpServer.preferredPort) async throws -> UInt16 {
        stop()
        if let port = NWEndpoint.Port(rawValue: preferred), let bound = try? await listen(on: port) {
            return bound
        }
        return try await listen(on: .any)
    }

    public func stop() {
        queue.sync {
            listener?.cancel()
            listener = nil
            boundPort = 0
            let open = Array(connections.values)
            connections.removeAll()
            open.forEach { $0.close() }
        }
    }

    private func listen(on port: NWEndpoint.Port) async throws -> UInt16 {
        let parameters = NWParameters.tcp
        parameters.allowLocalEndpointReuse = true
        parameters.requiredInterfaceType = .loopback
        let candidate = try NWListener(using: parameters, on: port)
        return try await withCheckedThrowingContinuation { continuation in
            var settled = false
            candidate.newConnectionHandler = { [weak self] in self?.accept($0) }
            candidate.stateUpdateHandler = { [weak self] state in
                guard !settled else { return }
                switch state {
                case .ready:
                    settled = true
                    let bound = candidate.port?.rawValue ?? 0
                    self?.boundPort = bound
                    continuation.resume(returning: bound)
                case let .failed(error):
                    settled = true
                    candidate.cancel()
                    continuation.resume(throwing: error)
                case .cancelled:
                    settled = true
                    continuation.resume(throwing: CancellationError())
                default:
                    break
                }
            }
            queue.async { [self] in
                listener = candidate
                candidate.start(queue: queue)
            }
        }
    }

    private func accept(_ connection: NWConnection) {
        guard connections.count < limits.maxConnections else {
            connection.cancel()
            return
        }
        let handler = DumpConnection(
            connection,
            queue: queue,
            limits: limits,
            onEvent: { [weak self] in self?.subject.send($0) },
            onClose: { [weak self] in self?.connections[$0] = nil }
        )
        connections[handler.id] = handler
        handler.start()
    }
}
