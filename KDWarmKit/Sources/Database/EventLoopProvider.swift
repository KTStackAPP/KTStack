import Foundation
import NIOCore
import NIOPosix

/// The single process-wide `EventLoopGroup` shared by every NIO database driver (MySQL today,
/// PostgreSQL/Mongo later). Created lazily on first connection so a build that never opens the
/// database editor pays nothing, and torn down asynchronously at quit.
///
/// Quit invariant the rest of the app must honour: close DB connections → `await shutdown()`
/// (off the main thread, bounded) → boot out the launchd engines. Shutting the group down before
/// the engines disappear lets in-flight connections close cleanly; doing it on the main thread
/// would block the terminate handler, so callers always `await` it from a detached context.
public final class EventLoopProvider: @unchecked Sendable {
    public static let shared = EventLoopProvider()

    public enum ProviderError: Error {
        /// `group()` was called after `shutdown()` began. A connection opened on a torn-down group
        /// would never be cleaned up, so the provider refuses rather than resurrecting it.
        case shutDown
        /// Graceful shutdown didn't finish within `shutdownDeadline`. The provider is already terminal;
        /// the quit path should log and proceed rather than wait further.
        case shutdownTimedOut
    }

    /// Upper bound on how long `shutdown()` waits for a graceful teardown before giving up. The quit
    /// path is terminal anyway (the process is exiting), so a wedged connection must not stall it
    /// indefinitely — past this deadline the provider is already marked terminal and we return.
    public static let shutdownDeadline: Duration = .seconds(3)

    private let lock = NSLock()
    private var loopGroup: MultiThreadedEventLoopGroup?
    private var didShutdown = false

    /// Private so `shared` is the only instance: a second provider would own a group the quit path
    /// never tears down. Internal tests reach the singleton, not a fresh instance.
    private init() {}

    /// The shared group, created on first access. One loop thread comfortably serves the editor's
    /// handful of pooled connections; revisit only if profiling shows event-loop contention. Throws
    /// once `shutdown()` has begun so a late query can't spin up a fresh group that nothing tears
    /// down (guards against both the leak and a bind-to-a-dying-group race).
    public func group() throws -> any EventLoopGroup {
        lock.lock(); defer { lock.unlock() }
        if didShutdown { throw ProviderError.shutDown }
        if let loopGroup { return loopGroup }
        let created = MultiThreadedEventLoopGroup(numberOfThreads: 1)
        loopGroup = created
        return created
    }

    /// Gracefully shut the group down and mark the provider terminal so it can't be resurrected. A
    /// no-op if never created. Idempotent: the flag is set under the lock, so a second call (or one
    /// after a never-started run) returns immediately.
    ///
    /// Bounded by `shutdownDeadline`: the group is nilled and the terminal flag set up front, so even
    /// if a wedged connection never drains, the race below abandons the wait and the provider stays
    /// terminal. A timeout throws `ProviderError.shutdownTimedOut` so the quit path can log-and-proceed
    /// rather than hang the terminate handler.
    public func shutdown() async throws {
        lock.lock()
        let existing = loopGroup
        loopGroup = nil
        didShutdown = true
        lock.unlock()
        guard let existing else { return }

        try await withThrowingTaskGroup(of: Void.self) { group in
            group.addTask { try await existing.shutdownGracefully() }
            group.addTask {
                try await Task.sleep(for: Self.shutdownDeadline)
                throw ProviderError.shutdownTimedOut
            }
            defer { group.cancelAll() }
            try await group.next()
        }
    }
}
