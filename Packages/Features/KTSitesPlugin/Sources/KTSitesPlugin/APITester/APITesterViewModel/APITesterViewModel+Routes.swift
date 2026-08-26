import Foundation
import KTPlatformContracts

extension APITesterViewModel {
    func load(site: SiteSummary) async {
        guard !isLoadingRoutes else { return }
        isLoadingRoutes = true
        loadError = nil
        metadataWarning = nil
        siteKey = site.domain
        variables = APIVariableStore.load(siteKey: siteKey).map {
            EditablePair(key: $0.name, value: $0.value, enabled: $0.enabled)
        }
        let folder = URL(fileURLWithPath: site.path)
        guard LaravelSiteProbe().isLaravel(siteAt: folder) else {
            await loadDiscovered(site: site, folder: folder)
            isLoadingRoutes = false
            return
        }
        showsTabs = true
        isGenericMode = false
        do {
            let outcome = try await routeIntrospection.introspectRoutes(siteFolder: folder, phpVersion: site.phpVersion)
            routes = outcome.routes
            metadataWarning = outcome.metadataOnly ? outcome.warning : nil
            if let first = visibleRoutes.first {
                select(first)
            } else if let firstAny = routes.first {
                tab = firstAny.isApi ? .api : .web
                select(firstAny)
            } else {
                newRequest()
            }
        } catch {
            routes = []
            loadError = error.localizedDescription
        }
        isLoadingRoutes = false
    }

    func loadDiscovered(site: SiteSummary, folder: URL) async {
        showsTabs = false
        let scheme = site.secure ? "https" : "http"
        let baseURL = URL(string: "\(scheme)://\(site.domain)")
        let discovered = await Task.detached(priority: .userInitiated) {
            await GenericRouteDiscovery().discover(baseURL: baseURL, folder: folder)
        }.value
        if discovered.isEmpty {
            isGenericMode = true
            routes = []
            newRequest()
        } else {
            isGenericMode = false
            routes = discovered
            if let first = visibleRoutes.first { select(first) } else { newRequest() }
        }
    }
}
