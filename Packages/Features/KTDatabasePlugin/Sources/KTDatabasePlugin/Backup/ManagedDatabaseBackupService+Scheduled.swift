import Foundation
import KTPlatformContracts
import KTStackCore

extension ManagedDatabaseBackupService: ScheduledDatabaseBackupProviding {
    public func installedEngines() -> [DatabaseEngine] {
        DatabaseEngine.allCases.filter { tools.isInstalled($0) }
    }

    public func userDatabases(_ engine: DatabaseEngine) async throws -> [String] {
        let profile = Self.managedProfile(for: engine)
        let names: [String]
        if engine == .mongodb {
            names = try await MongoDriver(profile: profile, password: nil, tools: tools).listDatabases().map(\.name)
        } else {
            guard let driver = RelationalDrivers.factory(tools: tools)(profile, nil) else {
                throw DatabaseError.connection("No driver for \(engine.rawValue).")
            }
            do {
                names = try await driver.backupDatabaseNames()
                await driver.closeSession()
            } catch {
                await driver.closeSession()
                throw error
            }
        }
        return BackupSession.userDatabaseNames(names, for: profile.kind).sorted()
    }

    public func stageBackup(engine: DatabaseEngine, databases: [String], into directory: URL) async throws -> URL {
        guard tools.isInstalled(engine) else {
            throw DatabaseError.connection("\(engine.rawValue) isn't installed in KTStack.")
        }
        let profile = Self.managedProfile(for: engine)
        guard let provider = providerFor(profile.kind) else {
            throw DatabaseError.connection("Backup tools for \(engine.rawValue) aren't installed.")
        }
        return try await session.library.stage(
            kind: profile.kind, profile: profile, databases: databases,
            using: provider, password: nil,
            engineVersion: session.resolveEngineVersion(profile.kind),
            in: directory
        )
    }

    public func importStagedBackup(at directory: URL) throws -> [String] {
        try session.library.importSet(from: directory).databases
    }
}
