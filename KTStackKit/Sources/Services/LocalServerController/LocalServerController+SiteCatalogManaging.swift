import Foundation
import KTPlatformContracts
import KTStackCore

extension SiteSummary {
    init(_ site: Site) {
        self.init(
            id: site.id,
            name: site.name,
            path: site.path,
            docroot: site.docroot,
            domain: site.domain,
            phpVersion: site.phpVersion,
            kind: SiteKind(rawValue: site.type.rawValue) ?? .php,
            databaseName: site.databaseName,
            secure: site.secure,
            nodePort: site.nodePort,
            nodeCommand: site.nodeCommand,
            engine: SiteServerEngine(rawValue: site.serverEngine.rawValue) ?? .nginx,
            backendPort: site.backendPort,
            proxyTarget: site.proxyTarget
        )
    }
}

extension LocalServerController: SiteCatalogManaging {
    public var catalog: SiteCatalogState {
        SiteCatalogState(sites: registry.sites.map(SiteSummary.init), tld: registry.tld)
    }

    // Stream dựng trên registry.objectWillChange: onRegistryChanged khi server idle chỉ refreshWatches,
    // không mutate @Published nào của server, nên tick phải đến từ registry.
    public func catalogStream() -> AsyncStream<SiteCatalogState> {
        registry.snapshotStream { self.catalog }
    }

    public func setPHPVersion(_ id: UUID, _ version: String) {
        guard let site = registry.sites.first(where: { $0.id == id }) else { return }
        registry.setPHPVersion(site, to: version)
    }

    public func editDomain(_ id: UUID, _ domain: String) throws {
        guard let site = registry.sites.first(where: { $0.id == id }) else { return }
        try registry.editDomain(site, to: domain)
    }

    public func validateDomain(_ domain: String, excluding id: UUID?) throws {
        try registry.validateDomain(domain, excluding: id)
    }

    public func setSecure(_ id: UUID, _ secure: Bool) {
        guard let site = registry.sites.first(where: { $0.id == id }) else { return }
        setSiteSecure(site, secure)
    }

    public func setNodePort(_ id: UUID, _ port: Int?) {
        guard let site = registry.sites.first(where: { $0.id == id }) else { return }
        setNodePort(site, port)
    }

    public func setEngine(_ id: UUID, _ engine: SiteServerEngine) {
        guard let site = registry.sites.first(where: { $0.id == id }) else { return }
        setSiteEngine(site, WebServerEngine(rawValue: engine.rawValue) ?? .nginx)
    }

    public func setProxyTarget(_ id: UUID, _ target: String) throws {
        guard let site = registry.sites.first(where: { $0.id == id }) else { return }
        let parsed: ProxyTarget
        switch ProxyTarget.parse(target) {
        case let .success(value): parsed = value
        case let .failure(error): throw error
        }
        try registry.validateProxyTarget(parsed, for: site)
        registry.setProxyTarget(site, parsed)
    }
}
