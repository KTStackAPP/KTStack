import Foundation
import KTStackCore

/// Adapts the existing `DumpService` to the engine-agnostic `BackupProvider`. MySQL has no atomic
/// `RENAME DATABASE`, so `.overwrite` uses the documented fallback to the temp-swap invariant: a
/// verified pre-restore safety dump with auto-rollback, never destroying the only copy until the new
/// restore has loaded.
public struct MySQLBackupProvider: BackupProvider {
    private let dumpService: DumpService
    private let safetyDirectory: URL

    public init(
        dumpService: DumpService,
        safetyDirectory: URL = AppSupportPaths().backups.appendingPathComponent("safety", isDirectory: true)
    ) {
        self.dumpService = dumpService
        self.safetyDirectory = safetyDirectory
    }

    public var fileExtension: String {
        "sql"
    }

    public var isAvailable: Bool {
        dumpService.requiredBinariesPresent
    }

    public func backup(
        profile: ConnectionProfile,
        password: String?,
        database: String,
        to artifactURL: URL
    ) async throws {
        try await dumpService.export(
            profile: profile,
            password: password,
            database: database,
            table: nil,
            to: artifactURL
        )
    }

    public func restore(
        profile: ConnectionProfile,
        password: String?,
        from artifactURL: URL,
        into target: RestoreTarget
    ) async throws {
        switch target {
        case let .newDatabase(name):
            try DumpService.validateIdentifier(name, label: "database")
            if try await dumpService.databaseExists(profile: profile, password: password, database: name) {
                throw DatabaseError.connection(
                    "A database named \"\(name)\" already exists. Choose another name or overwrite it explicitly."
                )
            }
            do {
                try await dumpService.importDump(
                    profile: profile,
                    password: password,
                    database: name,
                    from: artifactURL
                )
            } catch {
                try? await dumpService.runStatement(
                    profile: profile, password: password,
                    sql: try "DROP DATABASE IF EXISTS \(SQLDialect.forKind(.mysql).quoteIdent(name))"
                )
                throw error
            }
        case .overwrite:
            let database = artifactURL.deletingPathExtension().lastPathComponent
            try await overwrite(profile: profile, password: password, database: database, from: artifactURL)
        }
    }

    private func overwrite(
        profile: ConnectionProfile,
        password: String?,
        database: String,
        from artifactURL: URL
    ) async throws {
        try DumpService.validateIdentifier(database, label: "database")
        let quoted = try SQLDialect.forKind(.mysql).quoteIdent(database)

        try FileManager.default.createDirectory(
            at: safetyDirectory, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700]
        )
        let safety = safetyDirectory.appendingPathComponent("\(database)-before-restore-\(UUID().uuidString).sql")
        do {
            try await dumpService.export(profile: profile, password: password, database: database, table: nil, to: safety)
        } catch {
            try? FileManager.default.removeItem(at: safety)
            throw error
        }
        let safetySize = (try? FileManager.default.attributesOfItem(atPath: safety.path)[.size] as? Int64) ?? 0
        guard safetySize > 0 else {
            try? FileManager.default.removeItem(at: safety)
            throw DatabaseError.connection(
                "Pre-restore safety dump for \"\(database)\" is empty; aborting before any destructive step."
            )
        }

        do {
            try await replace(database, quoted: quoted, with: artifactURL, profile: profile, password: password)
        } catch {
            let restoreError = Self.message(error)
            do {
                try await replace(database, quoted: quoted, with: safety, profile: profile, password: password)
            } catch {
                throw DatabaseError.connection(
                    "Restore failed (\(restoreError)) and rolling back \"\(database)\" also failed (\(Self.message(error))). "
                        + "The original data is saved at \(safety.path)."
                )
            }
            try? FileManager.default.removeItem(at: safety)
            throw DatabaseError.connection("Restore failed and the original \"\(database)\" was rolled back: \(restoreError)")
        }
        try? FileManager.default.removeItem(at: safety)
    }

    private func replace(
        _ database: String,
        quoted: String,
        with dump: URL,
        profile: ConnectionProfile,
        password: String?
    ) async throws {
        try await dumpService.runStatement(profile: profile, password: password, sql: "DROP DATABASE IF EXISTS \(quoted)")
        try await dumpService.importDump(profile: profile, password: password, database: database, from: dump)
    }

    private static func message(_ error: Error) -> String {
        (error as? DatabaseError)?.message ?? error.localizedDescription
    }
}
