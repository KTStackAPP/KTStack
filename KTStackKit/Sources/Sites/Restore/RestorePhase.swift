import Foundation

public enum RestorePhase: String, Sendable, Equatable {
    case detecting
    case extracting
    case reconcilingCore
    case creatingDatabase
    case importingDatabase
    case writingConfig
    case registeringSite
    case searchReplace
    case configuringServer
    case done
}

public struct RestoreEvent: Sendable, Equatable {
    public let phase: RestorePhase
    public let message: String

    public init(phase: RestorePhase, message: String) {
        self.phase = phase
        self.message = message
    }
}

public struct RestoreRequest: Sendable {
    public let backupFile: URL
    public let siteName: String
    public let phpVersion: String
    public let secure: Bool

    public init(backupFile: URL, siteName: String, phpVersion: String, secure: Bool) {
        self.backupFile = backupFile
        self.siteName = siteName
        self.phpVersion = phpVersion
        self.secure = secure
    }
}

public struct RestoreOutcome: Sendable {
    public let site: Site
    public let warnings: [String]

    public init(site: Site, warnings: [String]) {
        self.site = site
        self.warnings = warnings
    }
}

public enum RestoreServiceError: LocalizedError, Equatable {
    case phpVersionNotInstalled(String)
    case sourceURLUnresolved

    public var errorDescription: String? {
        switch self {
        case .phpVersionNotInstalled(let version):
            return "PHP \(version) is not installed. Install it first, then retry the restore."
        case .sourceURLUnresolved:
            return "Could not determine the backup's original site address for search-replace."
        }
    }
}
