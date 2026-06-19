import Foundation

public final class RestartPolicy: @unchecked Sendable {
    public struct Outcome: Sendable, Equatable {
        public let status: ServiceStatus
        public let exhausted: Bool
    }

    public let errorAfter: TimeInterval

    private let lock = NSLock()
    private var firstFailure: [ServiceKind: Date] = [:]
    private let now: @Sendable () -> Date

    public init(errorAfter: TimeInterval = 20, now: @escaping @Sendable () -> Date = { Date() }) {
        self.errorAfter = errorAfter
        self.now = now
    }

    public func record(_ kind: ServiceKind, healthy: Bool) -> Outcome {
        lock.lock(); defer { lock.unlock() }
        if healthy {
            firstFailure[kind] = nil
            return Outcome(status: .running, exhausted: false)
        }
        let start = firstFailure[kind] ?? now()
        firstFailure[kind] = start
        if now().timeIntervalSince(start) >= errorAfter {
            return Outcome(status: .error, exhausted: true)
        }
        return Outcome(status: .starting, exhausted: false)
    }

    public func reset(_ kind: ServiceKind) {
        lock.lock(); firstFailure[kind] = nil; lock.unlock()
    }

    public func isFailing(_ kind: ServiceKind) -> Bool {
        lock.lock(); defer { lock.unlock() }
        return firstFailure[kind] != nil
    }
}
