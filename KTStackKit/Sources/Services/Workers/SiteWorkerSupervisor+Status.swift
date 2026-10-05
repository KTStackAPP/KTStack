import Foundation
import KTPlatformContracts
import KTStackCore

extension SiteWorkerSupervisor {
    public func statuses(sites: [Site], serverRunning: Bool) -> SiteWorkersState {
        let loaded = serverRunning && !Self.desired(sites).isEmpty ? Set(loadedLabels()) : []
        var statuses: [UUID: SiteWorkerStatus] = [:]
        for site in sites where site.supportsWorkers {
            for worker in site.workers {
                statuses[worker.id] = status(site: site, worker: worker, serverRunning: serverRunning, loaded: loaded)
            }
        }
        return SiteWorkersState(statuses: statuses)
    }

    private func status(site: Site, worker: SiteWorker, serverRunning: Bool, loaded: Set<String>) -> SiteWorkerStatus {
        guard worker.enabled else { return .stopped }
        guard serverRunning else { return SiteWorkerStatus(state: .waitingForServer) }
        let label = self.label(site: site, worker: worker)
        let recorded = WorkerStatus.read(from: statusURL(label))
        if let recorded, recorded.state == .failedToStart {
            return SiteWorkerStatus(state: .failed, message: recorded.message)
        }
        guard loaded.contains(label), let recorded else {
            return SiteWorkerStatus(state: .starting)
        }
        return SiteWorkerStatus(
            state: Self.runState(recorded.state),
            restarts: recorded.restarts,
            lastExitStatus: recorded.lastExitStatus,
            nextAttemptAt: recorded.nextAttemptAt,
            message: recorded.message
        )
    }

    static func runState(_ state: WorkerStatus.State) -> SiteWorkerRunState {
        switch state {
        case .running: .running
        case .backoff: .backoff
        case .crashed: .crashed
        case .stopped: .starting
        case .failedToStart: .failed
        }
    }
}
