import Foundation

public extension BackupLibrary {
    func stage(
        kind: DatabaseKind,
        profile: ConnectionProfile,
        databases: [String],
        using provider: BackupProvider,
        password: String?,
        engineVersion: String?,
        in parent: URL
    ) async throws -> URL {
        guard !databases.isEmpty else {
            throw DatabaseError.connection("No databases selected to back up.")
        }
        let id = UUID()
        let setDir = parent.appendingPathComponent(id.uuidString, isDirectory: true)
        try fileManager.createDirectory(
            at: setDir,
            withIntermediateDirectories: true,
            attributes: [.posixPermissions: 0o700]
        )
        do {
            for database in databases {
                let artifact = try Self.safeArtifactURL(
                    database: database, fileExtension: provider.fileExtension, in: setDir
                )
                try await provider.backup(profile: profile, password: password, database: database, to: artifact)
            }
            let set = BackupSet(
                id: id, kind: kind, engineVersion: engineVersion,
                profileName: profile.name, host: profile.host, profileID: profile.id, port: profile.port,
                databases: databases, createdAt: Date(),
                sizeBytes: Self.directorySize(setDir, fileManager: fileManager)
            )
            try writeMeta(set, in: setDir)
            return setDir
        } catch {
            try? fileManager.removeItem(at: setDir)
            throw error
        }
    }
}
