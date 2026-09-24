import Foundation
import Network

final class DumpConnection: @unchecked Sendable {
    private let connection: NWConnection
    private let queue: DispatchQueue
    private let limits: DumpServerLimits
    private let onEvent: (DumpEvent) -> Void
    private let onClose: (ObjectIdentifier) -> Void
    private var buffer = Data()
    private var received = 0
    private var idle: DispatchWorkItem?
    private var closed = false

    var id: ObjectIdentifier { ObjectIdentifier(self) }

    init(
        _ connection: NWConnection,
        queue: DispatchQueue,
        limits: DumpServerLimits,
        onEvent: @escaping (DumpEvent) -> Void,
        onClose: @escaping (ObjectIdentifier) -> Void
    ) {
        self.connection = connection
        self.queue = queue
        self.limits = limits
        self.onEvent = onEvent
        self.onClose = onClose
    }

    func start() {
        connection.start(queue: queue)
        armIdleTimer()
        receive()
    }

    func close() {
        guard !closed else { return }
        closed = true
        idle?.cancel()
        connection.cancel()
        onClose(id)
    }

    private func armIdleTimer() {
        idle?.cancel()
        let item = DispatchWorkItem { [weak self] in self?.close() }
        idle = item
        queue.asyncAfter(deadline: .now() + limits.idleTimeout, execute: item)
    }

    private func receive() {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self] content, _, isComplete, error in
            guard let self, !closed else { return }
            if let content {
                received += content.count
                guard received <= limits.maxConnectionBytes else { return close() }
                buffer.append(content)
                drainLines()
                armIdleTimer()
            }
            if isComplete || error != nil { close() } else { receive() }
        }
    }

    private func drainLines() {
        while let newline = buffer.firstIndex(of: UInt8(ascii: "\n")) {
            let line = buffer[buffer.startIndex..<newline]
            if !line.isEmpty, let event = try? DumpEventDecoder.decode(line: Data(line)) { onEvent(event) }
            buffer = Data(buffer[buffer.index(after: newline)...])
        }
    }
}
