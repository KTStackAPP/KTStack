import Foundation
import KTPlatformContracts
import KTStackCore

extension KTIPCCommandDispatcher {
    func handleWorkersList(request: KTIPCRequest) async -> KTIPCResponse {
        guard let server = await serverProvider() else {
            return .fail("Server controller unavailable", id: request.id)
        }
        let filter = request.params?["site"]
        let (sites, running) = await MainActor.run { (server.registry.sites, server.isRunning) }
        let selected = sites.filter { site in
            site.supportsWorkers && filter.map { Self.matches(site, $0) } != false
        }
        if let filter, selected.isEmpty {
            return .fail("No PHP site matches '\(filter)'", id: request.id)
        }
        let state = server.workers.statuses(sites: selected, serverRunning: running)
        let list = selected.flatMap { site in
            site.workers.map { worker in
                let status = state.status(of: worker.id)
                return KTIPCWorkerInfo(
                    site: site.domain,
                    name: worker.name,
                    command: worker.command,
                    enabled: worker.enabled,
                    state: status.state.rawValue,
                    restarts: status.restarts,
                    lastExitStatus: status.lastExitStatus
                )
            }
        }
        guard let data = try? JSONEncoder().encode(list), let text = String(data: data, encoding: .utf8) else {
            return .fail("Failed to encode workers", id: request.id)
        }
        return .ok(text, id: request.id)
    }

    func handleWorkerAction(request: KTIPCRequest) async -> KTIPCResponse {
        guard let siteName = request.params?["site"], let workerName = request.params?["worker"] else {
            return .fail("Missing 'site' or 'worker' parameter", id: request.id)
        }
        guard let server = await serverProvider() else {
            return .fail("Server controller unavailable", id: request.id)
        }
        return await MainActor.run {
            guard let site = server.registry.sites.first(where: { Self.matches($0, siteName) }) else {
                return .fail("Site not found: \(siteName)", id: request.id)
            }
            guard let worker = site.workers.first(where: { $0.name == workerName }) else {
                let names = site.workers.map(\.name).joined(separator: ", ")
                return .fail("No worker '\(workerName)' on \(site.domain). Workers: \(names.isEmpty ? "none" : names)", id: request.id)
            }
            return Self.apply(request.method, server: server, site: site, worker: worker, id: request.id)
        }
    }

    @MainActor
    private static func apply(
        _ method: String,
        server: LocalServerController,
        site: Site,
        worker: SiteWorker,
        id: String?
    ) -> KTIPCResponse {
        let later = server.isRunning ? "" : " (it starts with the server)"
        switch method {
        case "workers.start":
            guard !worker.enabled else { return .ok("\(worker.name) is already started on \(site.domain)", id: id) }
            server.startWorker(siteID: site.id, workerID: worker.id)
            return .ok("Starting \(worker.name) on \(site.domain)\(later)", id: id)
        case "workers.stop":
            guard worker.enabled else { return .ok("\(worker.name) is already stopped on \(site.domain)", id: id) }
            server.stopWorker(siteID: site.id, workerID: worker.id)
            return .ok("Stopping \(worker.name) on \(site.domain)", id: id)
        default:
            guard worker.enabled, server.isRunning else {
                return .fail("\(worker.name) is not running on \(site.domain); start it first", id: id)
            }
            server.restartWorker(siteID: site.id, workerID: worker.id)
            return .ok("Restarting \(worker.name) on \(site.domain)", id: id)
        }
    }

    private static func matches(_ site: Site, _ name: String) -> Bool {
        site.domain == name || site.name == name
    }
}
