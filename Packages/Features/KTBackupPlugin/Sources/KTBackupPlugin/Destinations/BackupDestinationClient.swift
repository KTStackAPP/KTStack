import Foundation

public typealias BackupProgressHandler = @Sendable (Double) -> Void

public protocol BackupDestinationClient: Sendable {
    func testConnection() async throws -> String
    func listFolders(parent: RemoteFolder?) async throws -> [RemoteFolder]
    func createFolder(named name: String, in parent: RemoteFolder?) async throws -> RemoteFolder
    func upload(_ request: BackupUploadRequest, progress: @escaping BackupProgressHandler) async throws -> RemoteBackupObject
    func list(ownedBy planID: UUID) async throws -> [RemoteBackupObject]
    func moveToTrash(_ object: RemoteBackupObject) async throws -> TrashOutcome
    func download(_ object: RemoteBackupObject, to fileURL: URL, progress: @escaping BackupProgressHandler) async throws
}

public enum BackupDestinationError: Error, LocalizedError, Equatable {
    case notConfigured(String)
    case unavailable(String)
    case verificationFailed(String)
    case remote(String)
    case missingCredentials(String)

    public var errorDescription: String? {
        switch self {
        case let .notConfigured(detail): "Destination isn't configured: \(detail)"
        case let .unavailable(detail): detail
        case let .verificationFailed(detail): "Upload verification failed: \(detail)"
        case let .remote(detail): detail
        case let .missingCredentials(detail): "Missing credentials: \(detail)"
        }
    }
}
