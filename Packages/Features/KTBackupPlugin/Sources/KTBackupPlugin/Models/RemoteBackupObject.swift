import Foundation

public struct RemoteBackupObject: Codable, Equatable, Identifiable, Sendable {
    public var id: String
    public var name: String
    public var sizeBytes: Int64
    public var createdAt: Date?
    public var planID: UUID?
    public var sha256: String?

    public init(id: String, name: String, sizeBytes: Int64, createdAt: Date?, planID: UUID?, sha256: String?) {
        self.id = id
        self.name = name
        self.sizeBytes = sizeBytes
        self.createdAt = createdAt
        self.planID = planID
        self.sha256 = sha256
    }
}

public struct RemoteFolder: Codable, Equatable, Hashable, Identifiable, Sendable {
    public var id: String
    public var name: String

    public init(id: String, name: String) {
        self.id = id
        self.name = name
    }
}

public enum TrashOutcome: Equatable, Sendable {
    case trashed
    case skipped(String)
}

public struct BackupUploadRequest: Sendable {
    public var fileURL: URL
    public var fileName: String
    public var planFolderName: String
    public var planID: UUID
    public var sha256: String
    public var sizeBytes: Int64

    public init(fileURL: URL, fileName: String, planFolderName: String, planID: UUID, sha256: String, sizeBytes: Int64) {
        self.fileURL = fileURL
        self.fileName = fileName
        self.planFolderName = planFolderName
        self.planID = planID
        self.sha256 = sha256
        self.sizeBytes = sizeBytes
    }
}
