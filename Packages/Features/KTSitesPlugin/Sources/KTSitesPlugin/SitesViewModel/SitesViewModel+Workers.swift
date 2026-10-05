import Foundation
import KTPlatformContracts
import KTStackCore

struct SiteWorkersSummary: Equatable {
    let total: Int
    let active: Int
    let failing: Int

    var isEmpty: Bool { total == 0 }

    var label: String {
        if failing > 0 { return failing == 1 ? "1 worker failing" : "\(failing) workers failing" }
        return total == 1 ? "\(active)/1 worker" : "\(active)/\(total) workers"
    }
}

extension SitesViewModel {
    func startWorkerUpdates() {
        guard workerTask == nil else { return }
        let stream = workerManager.workersStateStream()
        workerTask = Task { [weak self] in
            for await next in stream {
                guard let self else { return }
                if workers != next { workers = next }
            }
        }
    }

    func stopWorkerUpdates() {
        workerTask?.cancel()
        workerTask = nil
    }

    func workerStatus(_ worker: SiteWorker) -> SiteWorkerStatus {
        guard worker.enabled else { return .stopped }
        if let status = workers.statuses[worker.id], status.state != .stopped { return status }
        return SiteWorkerStatus(state: server.isRunning ? .starting : .waitingForServer)
    }

    func workersSummary(for site: SiteSummary) -> SiteWorkersSummary {
        guard site.kind == .php, !site.path.isEmpty else { return SiteWorkersSummary(total: 0, active: 0, failing: 0) }
        let statuses = site.workers.map(workerStatus)
        return SiteWorkersSummary(
            total: site.workers.count,
            active: statuses.filter(\.state.isActive).count,
            failing: statuses.filter(\.needsAttention).count
        )
    }

    func isLaravel(_ site: SiteSummary) -> Bool {
        frameworks[site.id] == .laravel
    }

    func setWorkers(_ siteID: UUID, _ workers: [SiteWorker]) throws {
        try workerManager.setWorkers(siteID, workers)
    }

    func startWorker(_ siteID: UUID, _ worker: SiteWorker) {
        workerManager.startWorker(siteID: siteID, workerID: worker.id)
    }

    func stopWorker(_ siteID: UUID, _ worker: SiteWorker) {
        workerManager.stopWorker(siteID: siteID, workerID: worker.id)
    }

    func restartWorker(_ siteID: UUID, _ worker: SiteWorker) {
        workerManager.restartWorker(siteID: siteID, workerID: worker.id)
    }

    func openWorkerLogs(_ siteID: UUID, _ worker: SiteWorker) {
        guard let sourceID = workerManager.workerLogSourceID(siteID: siteID, workerID: worker.id) else { return }
        route(.logs(sourceID: sourceID))
    }
}
