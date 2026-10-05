import Foundation

public struct LocalFolderClient: BackupDestinationClient {
    public typealias TrashHandler = @Sendable (URL) throws -> Void
    static let checksumExtension = "sha256"

    public let folder: URL
    let trash: TrashHandler

    public init(folder: URL, trash: @escaping TrashHandler = LocalFolderClient.systemTrash) {
        self.folder = folder
        self.trash = trash
    }

    public static let systemTrash: TrashHandler = { url in
        try FileManager.default.trashItem(at: url, resultingItemURL: nil)
    }

    public func testConnection() async throws -> String {
        try requireFolder()
        let probe = folder.appendingPathComponent(".ktstack-probe-\(UUID().uuidString)")
        do {
            try Data("probe".utf8).write(to: probe)
            try FileManager.default.removeItem(at: probe)
        } catch {
            throw BackupDestinationError.unavailable("KTStack can't write to \(folder.path): \(error.localizedDescription)")
        }
        guard let free = freeSpace() else { return "Folder is writable." }
        return "Folder is writable · \(ByteCountFormatter.string(fromByteCount: free, countStyle: .file)) free"
    }

    public func listFolders(parent: RemoteFolder?) async throws -> [RemoteFolder] {
        let base = parent.map { URL(fileURLWithPath: $0.id, isDirectory: true) } ?? folder
        return try subdirectories(of: base).map { RemoteFolder(id: $0.path, name: $0.lastPathComponent) }
    }

    public func createFolder(named name: String, in parent: RemoteFolder?) async throws -> RemoteFolder {
        let base = parent.map { URL(fileURLWithPath: $0.id, isDirectory: true) } ?? folder
        let created = base.appendingPathComponent(name, isDirectory: true)
        try FileManager.default.createDirectory(at: created, withIntermediateDirectories: true)
        return RemoteFolder(id: created.path, name: name)
    }

    public func upload(_ request: BackupUploadRequest, progress: @escaping BackupProgressHandler) async throws -> RemoteBackupObject {
        try requireFolder()
        let directory = folder.appendingPathComponent(request.planFolderName, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let target = directory.appendingPathComponent(request.fileName)
        let partial = directory.appendingPathComponent(".\(request.fileName).partial")
        try? FileManager.default.removeItem(at: partial)
        defer { try? FileManager.default.removeItem(at: partial) }
        try FileManager.default.copyItem(at: request.fileURL, to: partial)
        progress(0.9)
        guard try FileDigest.size(of: partial) == request.sizeBytes, try FileDigest.sha256Hex(of: partial) == request.sha256 else {
            throw BackupDestinationError.verificationFailed("the copy in \(directory.path) doesn't match the archive.")
        }
        try? FileManager.default.removeItem(at: target)
        try FileManager.default.moveItem(at: partial, to: target)
        try Data("\(request.sha256)  \(request.fileName)\n".utf8).write(to: checksumURL(for: target))
        progress(1)
        return try object(at: target, planID: request.planID)
    }

    public func list(ownedBy planID: UUID) async throws -> [RemoteBackupObject] {
        try requireFolder()
        let directories = [folder] + (try subdirectories(of: folder))
        return try directories.flatMap { directory in
            try FileManager.default.contentsOfDirectory(atPath: directory.path)
                .filter { BackupArchiveNaming.belongs($0, to: planID) }
                .map { try object(at: directory.appendingPathComponent($0), planID: planID) }
        }
    }

    public func moveToTrash(_ object: RemoteBackupObject) async throws -> TrashOutcome {
        let url = URL(fileURLWithPath: object.id)
        do {
            try trash(url)
        } catch {
            return .skipped("Couldn't move \(object.name) to the Trash (\(error.localizedDescription)); it was kept.")
        }
        let checksum = checksumURL(for: url)
        if FileManager.default.fileExists(atPath: checksum.path) {
            try? trash(checksum)
        }
        return .trashed
    }

    public func download(_ object: RemoteBackupObject, to fileURL: URL, progress: @escaping BackupProgressHandler) async throws {
        try? FileManager.default.removeItem(at: fileURL)
        try FileManager.default.copyItem(at: URL(fileURLWithPath: object.id), to: fileURL)
        progress(1)
    }
}
