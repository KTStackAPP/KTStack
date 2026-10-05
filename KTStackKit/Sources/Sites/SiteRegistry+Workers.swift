import Foundation
import KTStackCore

public extension SiteRegistry {
    func setWorkers(_ site: Site, _ workers: [SiteWorker]) throws {
        if let error = SiteWorkers.validate(workers) {
            throw RegistryError.invalidWorkers(error.errorDescription ?? "Invalid workers.")
        }
        update(site.id) { $0.workers = workers }
    }

    func setWorkerEnabled(siteID: UUID, workerID: UUID, _ enabled: Bool) {
        update(siteID) { site in
            guard let index = site.workers.firstIndex(where: { $0.id == workerID }) else { return }
            site.workers[index].enabled = enabled
        }
    }
}
