import Foundation
import KTPlatformContracts
import KTStackCore

extension SitesViewModel {
    func toggleServer() {
        serverControl.toggle()
    }

    func setPHP(_ id: UUID, _ version: String) {
        catalog.setPHPVersion(id, version)
    }

    func editDomain(_ id: UUID, _ domain: String) throws {
        try catalog.editDomain(id, domain)
    }

    func setSecure(_ id: UUID, _ secure: Bool) {
        catalog.setSecure(id, secure)
    }

    func setNodePort(_ id: UUID, _ port: Int?) throws {
        if let port, let other = sites.first(where: { $0.id != id && $0.nodePort == port }) {
            throw SiteActionError.duplicateNodePort(port: port, domain: other.domain)
        }
        catalog.setNodePort(id, port)
    }

    func setEngine(_ id: UUID, _ engine: SiteServerEngine) {
        catalog.setEngine(id, engine)
    }

    func setProxyTarget(_ id: UUID, _ raw: String) throws {
        // Validate client-side để báo lỗi ngay; platform validate lại khi ghi.
        if case let .failure(error) = ProxyTarget.parse(raw) {
            throw SiteActionError.invalidProxyTarget(message: error.localizedDescription)
        }
        try catalog.setProxyTarget(id, raw)
    }

    func installApache() {
        webEngineManager.installApache()
    }

    func isEndOfLife(_ version: String) -> Bool {
        runtimesManager.isEndOfLife(.php, version)
    }

    func startShare(_ site: SiteSummary) {
        sharingManager.startShare(TunnelSiteTarget(id: site.id, domain: site.domain, secure: site.secure))
    }

    func stopShare(siteID: UUID) {
        sharingManager.stopShare(siteID: siteID)
    }

    func enableDNS() { dnsManager.enable() }
    func disableDNS() { dnsManager.disable() }
    func resetDNS() { dnsManager.reset() }
    func refreshDNS() { dnsManager.refresh() }

    func logSourceID(for site: SiteSummary) -> String {
        "site-\(site.domain)-access"
    }

    func openLogs(_ site: SiteSummary) {
        route(.logs(sourceID: logSourceID(for: site)))
    }

    func remove(_ site: SiteSummary, deleteFolder: Bool, dropDatabase: Bool) async throws {
        try await provisioning.remove(site.id, deleteFolder: deleteFolder, dropDatabase: dropDatabase)
    }
}
