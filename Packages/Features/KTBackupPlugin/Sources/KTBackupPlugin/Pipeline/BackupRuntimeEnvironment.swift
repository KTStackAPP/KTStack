import Foundation
import KTPlatformContracts

public struct BackupSiteFolder: Equatable, Sendable {
    public var id: UUID
    public var name: String
    public var root: URL

    public init(id: UUID, name: String, root: URL) {
        self.id = id
        self.name = name
        self.root = root
    }
}

public protocol BackupRuntimeEnvironment: Sendable {
    func runningEngines() async -> Set<DatabaseEngine>
    func siteFolders(_ ids: [UUID]) async -> [BackupSiteFolder]
}

public struct StagedBackup: Equatable, Sendable {
    public var archiveURL: URL
    public var fileName: String
    public var sizeBytes: Int64
    public var sha256: String
    public var items: [BackupRunItem]
}

public enum StageOutcome: Equatable, Sendable {
    case staged(StagedBackup)
    case skipped(BackupSkipReason)
}

extension DatabaseEngine {
    var displayName: String {
        switch self {
        case .mysql: "MySQL"
        case .postgres: "PostgreSQL"
        case .mongodb: "MongoDB"
        }
    }
}
