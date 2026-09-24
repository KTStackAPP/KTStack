import Foundation

final class LoadedLabelsCache: @unchecked Sendable {
    private let lock = NSLock()
    private let ttl: TimeInterval
    private let fetch: @Sendable () -> Set<String>
    private var labels = Set<String>()
    private var fetchedAt = Date.distantPast
    private var refreshing = false
    private var generation = 0

    init(ttl: TimeInterval = 0.5, fetch: @escaping @Sendable () -> Set<String> = { LaunchAgentManager.loadedLabels() }) {
        self.ttl = ttl
        self.fetch = fetch
    }

    func contains(_ label: String) -> Bool {
        lock.lock()
        if fetchedAt == .distantPast, !refreshing {
            lock.unlock()
            return containsNow(label)
        }
        let stale = Date().timeIntervalSince(fetchedAt) > ttl
        let shouldRefresh = stale && !refreshing
        if shouldRefresh { refreshing = true }
        let started = generation
        let snapshot = labels
        lock.unlock()
        if shouldRefresh {
            DispatchQueue.global(qos: .utility).async { [self] in
                let fresh = fetch()
                lock.lock()
                if generation == started { labels = fresh; fetchedAt = Date() }
                refreshing = false
                lock.unlock()
            }
        }
        return snapshot.contains(label)
    }

    func containsNow(_ label: String) -> Bool {
        let fresh = fetch()
        lock.lock(); labels = fresh; fetchedAt = Date(); generation += 1; lock.unlock()
        return fresh.contains(label)
    }

    func markLoaded(_ label: String) {
        lock.lock(); labels.insert(label); fetchedAt = Date(); generation += 1; lock.unlock()
    }

    func markUnloaded(_ label: String) {
        lock.lock(); labels.remove(label); fetchedAt = Date(); generation += 1; lock.unlock()
    }

    func invalidate() {
        lock.lock(); fetchedAt = .distantPast; generation += 1; lock.unlock()
    }
}
