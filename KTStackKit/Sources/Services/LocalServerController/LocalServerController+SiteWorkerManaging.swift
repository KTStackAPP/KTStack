import Foundation
import KTPlatformContracts
import KTStackCore

extension LocalServerController: SiteWorkerManaging {
    static let workerStatusPollInterval: UInt64 = 2_000_000_000

    public var workersState: SiteWorkersState {
        workers.statuses(sites: registry.sites, serverRunning: isRunning)
    }

    public func workersStateStream() -> AsyncStream<SiteWorkersState> {
        AsyncStream { continuation in
            let task = Task { @MainActor [weak self] in
                var last: SiteWorkersState?
                while !Task.isCancelled {
                    guard let self else { break }
                    let next = await self.loadWorkersState()
                    if next != last {
                        last = next
                        continuation.yield(next)
                    }
                    try? await Task.sleep(nanoseconds: Self.workerStatusPollInterval)
                }
                continuation.finish()
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    public func setWorkers(_ siteID: UUID, _ workers: [SiteWorker]) throws {
        guard let site = registry.sites.first(where: { $0.id == siteID }) else { return }
        try registry.setWorkers(site, workers)
    }

    public func startWorker(siteID: UUID, workerID: UUID) {
        registry.setWorkerEnabled(siteID: siteID, workerID: workerID, true)
    }

    public func stopWorker(siteID: UUID, workerID: UUID) {
        registry.setWorkerEnabled(siteID: siteID, workerID: workerID, false)
    }

    public func restartWorker(siteID: UUID, workerID: UUID) {
        guard isRunning, let site = registry.sites.first(where: { $0.id == siteID }),
              let worker = site.workers.first(where: { $0.id == workerID }) else { return }
        let supervisor = self.workers
        Task.detached(priority: .userInitiated) { supervisor.restart(site: site, worker: worker) }
    }

    public func workerLogSourceID(siteID: UUID, workerID: UUID) -> String? {
        guard let site = registry.sites.first(where: { $0.id == siteID }),
              let worker = site.workers.first(where: { $0.id == workerID }) else { return nil }
        return LogCatalog.siteWorkerSourceID(domain: site.domain, worker: worker.name)
    }

    func loadWorkersState() async -> SiteWorkersState {
        let sites = registry.sites
        let running = isRunning
        let supervisor = self.workers
        return await Task.detached(priority: .utility) {
            supervisor.statuses(sites: sites, serverRunning: running)
        }.value
    }
}
