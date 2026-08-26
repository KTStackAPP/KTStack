import Foundation

// rawValue frozen == SiteType.rawValue (platform map theo raw value, test enforce).
public enum SiteKind: String, Sendable, CaseIterable {
    case php, staticSite, node, proxy
}

// rawValue frozen == WebServerEngine.rawValue.
public enum SiteServerEngine: String, Sendable, CaseIterable {
    case nginx, apache
}

// Projection của Site theo capability Sites: 17 field UI đọc. Không phải snapshot chung (Tunnel dùng
// TunnelSiteTarget, Logs dùng siteDomains).
public struct SiteSummary: Sendable, Equatable, Hashable, Identifiable {
    public let id: UUID
    public let name: String
    public let path: String
    public let docroot: String
    public let domain: String
    public let phpVersion: String
    public let kind: SiteKind
    public let databaseName: String?
    public let secure: Bool
    public let nodePort: Int?
    public let nodeCommand: String?
    public let engine: SiteServerEngine
    public let backendPort: Int?
    public let proxyTarget: String?
    public let aliases: [String]
    public let envVars: [String: String]
    public let frontDirectives: String?

    public init(
        id: UUID,
        name: String,
        path: String,
        docroot: String,
        domain: String,
        phpVersion: String,
        kind: SiteKind,
        databaseName: String?,
        secure: Bool,
        nodePort: Int?,
        nodeCommand: String?,
        engine: SiteServerEngine,
        backendPort: Int?,
        proxyTarget: String? = nil,
        aliases: [String] = [],
        envVars: [String: String] = [:],
        frontDirectives: String? = nil
    ) {
        self.id = id
        self.name = name
        self.path = path
        self.docroot = docroot
        self.domain = domain
        self.phpVersion = phpVersion
        self.kind = kind
        self.databaseName = databaseName
        self.secure = secure
        self.nodePort = nodePort
        self.nodeCommand = nodeCommand
        self.engine = engine
        self.backendPort = backendPort
        self.proxyTarget = proxyTarget
        self.aliases = aliases
        self.envVars = envVars
        self.frontDirectives = frontDirectives
    }
}

public struct SiteCatalogState: Sendable, Equatable {
    public var sites: [SiteSummary]
    public var tld: String

    public init(sites: [SiteSummary], tld: String) {
        self.sites = sites
        self.tld = tld
    }
}

public protocol SiteCatalogManaging: AnyObject {
    @MainActor var catalog: SiteCatalogState { get }
    @MainActor func catalogStream() -> AsyncStream<SiteCatalogState>
    @MainActor func setPHPVersion(_ id: UUID, _ version: String)
    @MainActor func editDomain(_ id: UUID, _ domain: String) throws
    @MainActor func validateDomain(_ domain: String, excluding id: UUID?) throws
    @MainActor func setSecure(_ id: UUID, _ secure: Bool)
    @MainActor func setNodePort(_ id: UUID, _ port: Int?)
    @MainActor func setEngine(_ id: UUID, _ engine: SiteServerEngine)
    @MainActor func setProxyTarget(_ id: UUID, _ target: String) throws
    @MainActor func setAliases(_ id: UUID, _ aliases: [String]) throws
    @MainActor func validateAliases(_ aliases: [String], for id: UUID) throws
    @MainActor func setEnvVars(_ id: UUID, _ env: [String: String]) throws
    // Fail-closed: nginx -t trước khi persist; tái dùng NginxIncludeSaveError.
    @MainActor func saveFrontDirectives(_ id: UUID, _ text: String) async throws
}

public struct SiteServerState: Sendable, Equatable {
    public var isRunning: Bool
    public var isBusy: Bool
    public var lastError: String?
    public var phpVersions: [String]

    public init(isRunning: Bool, isBusy: Bool, lastError: String?, phpVersions: [String]) {
        self.isRunning = isRunning
        self.isBusy = isBusy
        self.lastError = lastError
        self.phpVersions = phpVersions
    }
}

public protocol SiteServerControlling: AnyObject {
    @MainActor var serverState: SiteServerState { get }
    @MainActor func serverStates() -> AsyncStream<SiteServerState>
    @MainActor func toggle()
    func probeUpstream(host: String, port: Int) async -> Bool
}
