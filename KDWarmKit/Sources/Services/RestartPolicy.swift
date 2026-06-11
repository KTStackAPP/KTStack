import Foundation

/// App-level bounded retry/backoff that complements launchd's `KeepAlive`.
///
/// launchd restarts a crashed job at the OS level, but it THROTTLES relaunches (~10s minimum
/// between starts). So a crashed service is briefly unreachable before launchd brings it back. This
/// policy bridges that window: while a service has been unhealthy for less than `errorAfter` it is
/// reported `starting` (a launchd restart is expected); only after `errorAfter` of *continuous*
/// failure — long enough to cover the throttle + a restart + warm-up — does it settle into `error`
/// (a genuine restart storm), at which point the user must restart it manually. A single healthy
/// probe resets the clock.
///
/// The escalation is TIME-based, not probe-count-based, so the verdict is independent of the poll
/// interval (a count-based cap would fire in ~3 polls, well before launchd's 10s throttle).
public final class RestartPolicy: @unchecked Sendable {
    public struct Outcome: Sendable, Equatable {
        public let status: ServiceStatus
        public let exhausted: Bool
    }

    /// Continuous-failure duration before a service is declared `error` (must exceed launchd's ~10s
    /// relaunch throttle so a normal crash-recovery is never mislabelled).
    public let errorAfter: TimeInterval

    private let lock = NSLock()
    private var firstFailure: [ServiceKind: Date] = [:]
    private let now: @Sendable () -> Date

    public init(errorAfter: TimeInterval = 20, now: @escaping @Sendable () -> Date = { Date() }) {
        self.errorAfter = errorAfter
        self.now = now
    }

    /// Feed a probe result for `kind`; get back the status to publish.
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

    /// Clear the failure clock (called on an explicit user start/stop so a fresh attempt is clean).
    public func reset(_ kind: ServiceKind) {
        lock.lock(); firstFailure[kind] = nil; lock.unlock()
    }

    /// Whether `kind` currently has an open failure window (used by tests / diagnostics).
    public func isFailing(_ kind: ServiceKind) -> Bool {
        lock.lock(); defer { lock.unlock() }
        return firstFailure[kind] != nil
    }
}
