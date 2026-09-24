import Foundation

public extension DatabaseAdminModel {
    func backupAllDatabases(session: BackupSession) async -> BackupSet? {
        guard let profile = selectedProfile, let driver else {
            backupStatus = .failed("Connect to a database before backing up.")
            return nil
        }
        backupStatus = .running("Listing databases…")
        let dbs: [String]
        do {
            let all = try await driver.backupDatabaseNames()
            dbs = BackupSession.userDatabaseNames(all, for: profile.kind)
        } catch {
            backupStatus = .failed(Self.asDatabaseError(error).message)
            return nil
        }
        guard !dbs.isEmpty else {
            backupStatus = .failed("No user databases to back up (only system schemas were found).")
            return nil
        }
        backupStatus = .running("Backing up \(dbs.count) databases…")
        do {
            let set = try await session.create(profile: profile, password: passwordFor(profile), databases: dbs)
            backupStatus = .done("Backed up \(dbs.count) databases.")
            return set
        } catch {
            backupStatus = .failed(Self.asDatabaseError(error).message)
            return nil
        }
    }

    func restoreBackup(
        _ set: BackupSet,
        database: String,
        target: RestoreTarget,
        session: BackupSession,
        confirmedTarget: Bool = false
    ) async -> Bool {
        guard let profile = selectedProfile else { return false }
        guard !isReadOnlyConnection else {
            backupStatus = .failed("This connection is read-only; restore is disabled.")
            return false
        }
        backupStatus = .running("Restoring \(database)…")
        do {
            try await session.restore(
                set: set,
                database: database,
                profile: profile,
                password: passwordFor(profile),
                target: target,
                confirmedTarget: confirmedTarget
            )
            backupStatus = .done("Restored \(database).")
            return true
        } catch {
            backupStatus = .failed(Self.asDatabaseError(error).message)
            return false
        }
    }

    func deleteBackup(_ set: BackupSet, session: BackupSession) {
        do {
            try session.delete(set)
            backupStatus = .done("Deleted the backup set.")
        } catch {
            backupStatus = .failed(Self.asDatabaseError(error).message)
        }
    }

    func exportBackup(_ set: BackupSet, to destination: URL, session: BackupSession) {
        do {
            try session.exportSet(set, to: destination)
            backupStatus = .done("Exported backup to \(destination.lastPathComponent).")
        } catch {
            backupStatus = .failed(Self.asDatabaseError(error).message)
        }
    }
}
