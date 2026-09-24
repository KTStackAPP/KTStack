import Foundation

public struct DatabaseBackupArtifact: Sendable, Equatable {
    public let engine: DatabaseEngine
    public let database: String
    public let fileURL: URL

    public init(engine: DatabaseEngine, database: String, fileURL: URL) {
        self.engine = engine
        self.database = database
        self.fileURL = fileURL
    }

    public var hasContent: Bool {
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: fileURL.path, isDirectory: &isDirectory) else { return false }
        if isDirectory.boolValue {
            let children = (try? FileManager.default.contentsOfDirectory(atPath: fileURL.path)) ?? []
            return !children.isEmpty
        }
        let size = (try? FileManager.default.attributesOfItem(atPath: fileURL.path)[.size] as? NSNumber)?.int64Value ?? 0
        return size > 0
    }
}

public protocol DatabaseBackupProviding: Sendable {
    func backup(database: String, engine: DatabaseEngine?) async throws -> DatabaseBackupArtifact
}
