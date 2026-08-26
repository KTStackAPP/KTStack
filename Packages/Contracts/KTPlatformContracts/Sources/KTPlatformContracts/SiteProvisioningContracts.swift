import Foundation

public enum NewSiteKind: String, Sendable, CaseIterable, Identifiable {
    case wordpress, laravel, empty
    public var id: String { rawValue }

    public var label: String {
        switch self {
        case .wordpress: "WordPress"
        case .laravel: "Laravel"
        case .empty: "Empty Site"
        }
    }
}

public struct NewSiteRequest: Sendable {
    public let name: String
    public let kind: NewSiteKind
    public let phpVersion: String
    public let folder: URL
    public let domain: String
    public let databaseName: String?
    public let siteTitle: String
    public let adminUser: String
    public let adminEmail: String
    public let adminPassword: String

    public init(
        name: String,
        kind: NewSiteKind,
        phpVersion: String,
        folder: URL,
        domain: String,
        databaseName: String?,
        siteTitle: String = "",
        adminUser: String = "admin",
        adminEmail: String = "admin@example.com",
        adminPassword: String = ""
    ) {
        self.name = name
        self.kind = kind
        self.phpVersion = phpVersion
        self.folder = folder
        self.domain = domain
        self.databaseName = databaseName
        self.siteTitle = siteTitle.isEmpty ? name : siteTitle
        self.adminUser = adminUser
        self.adminEmail = adminEmail
        self.adminPassword = adminPassword
    }
}

public enum InstallPhase: String, Sendable, Equatable {
    case preparing, configuringDatabase, scaffolding, finalizing, done
}

public struct InstallEvent: Sendable, Equatable {
    public let phase: InstallPhase
    public let message: String
    public init(phase: InstallPhase, message: String) {
        self.phase = phase
        self.message = message
    }
}

public enum InstallError: LocalizedError, Equatable {
    case folderExists(String)
    public var errorDescription: String? {
        switch self {
        case let .folderExists(name): "A folder named “\(name)” already exists in your sites root."
        }
    }
}

public enum SiteImportError: LocalizedError, Equatable {
    case databaseExists(String)
    case alreadyRegistered(String)
    public var errorDescription: String? {
        switch self {
        case let .databaseExists(name):
            "A database named “\(name)” already exists. Disable “Create database” or rename the folder."
        case let .alreadyRegistered(name):
            "“\(name)” is already registered."
        }
    }
}

public struct FolderInspection: Sendable, Equatable {
    public let docroot: URL
    public let defaultDomain: String
    public let kind: SiteKind

    public init(docroot: URL, defaultDomain: String, kind: SiteKind) {
        self.docroot = docroot
        self.defaultDomain = defaultDomain
        self.kind = kind
    }
}

public struct ScannedFolder: Sendable, Equatable, Identifiable {
    public let folder: URL
    public let docroot: URL
    public let proposedDomain: String
    public let kind: SiteKind
    public let alreadyRegistered: Bool

    public var id: URL { folder }

    public init(folder: URL, docroot: URL, proposedDomain: String, kind: SiteKind, alreadyRegistered: Bool) {
        self.folder = folder
        self.docroot = docroot
        self.proposedDomain = proposedDomain
        self.kind = kind
        self.alreadyRegistered = alreadyRegistered
    }
}

public protocol SiteProvisioning: AnyObject {
    @MainActor func install(_ request: NewSiteRequest, enableHTTPS: Bool,
                            emit: @escaping @Sendable (InstallEvent) -> Void) async throws -> SiteSummary
    @MainActor func importFolder(_ folder: URL, domain: String, phpVersion: String,
                                 createDatabase: Bool, enableHTTPS: Bool) async throws -> SiteSummary
    @MainActor func registerFolder(_ folder: URL, phpVersion: String) throws -> SiteSummary
    @MainActor func addProxySite(name: String, domain: String, target: String,
                                 enableHTTPS: Bool) async throws -> SiteSummary
    @MainActor func remove(_ id: UUID, deleteFolder: Bool, dropDatabase: Bool) async throws
    nonisolated func scan(root: URL, tld: String, existingPaths: [String]) -> [ScannedFolder]
    nonisolated func inspect(folder: URL, tld: String) -> FolderInspection
}

public protocol SiteIDEConfiguring: Sendable {
    func writeVSCodeDebugConfig(projectRoot: URL, docroot: URL) throws -> URL
}
