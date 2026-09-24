import Foundation
import KTPlatformContracts
import KTStackCore

public struct ManagedDatabaseBackupService: DatabaseBackupProviding {
    private let tools: any DatabaseToolsProviding
    private let session: BackupSession
    private let providerFor: @Sendable (DatabaseKind) -> BackupProvider?

    public init(tools: any DatabaseToolsProviding, paths: AppSupportPaths = AppSupportPaths()) {
        self.init(
            tools: tools,
            session: .managed(tools: tools, paths: paths),
            providerFor: { BackupProviderFactory.provider(for: $0, tools: tools) }
        )
    }

    init(
        tools: any DatabaseToolsProviding,
        session: BackupSession,
        providerFor: @escaping @Sendable (DatabaseKind) -> BackupProvider?
    ) {
        self.tools = tools
        self.session = session
        self.providerFor = providerFor
    }

    public func backup(database: String, engine: DatabaseEngine?) async throws -> DatabaseBackupArtifact {
        let name = database.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty, !name.contains("/"), name != ".", name != ".." else {
            throw DatabaseError.connection("Invalid database name: \(database)")
        }
        let engine = try resolveEngine(engine)
        let profile = Self.managedProfile(for: engine)
        guard let provider = providerFor(profile.kind) else {
            throw DatabaseError.connection("Backup tools for \(engine.rawValue) aren't installed.")
        }
        let set = try await session.library.create(
            kind: profile.kind, profile: profile, databases: [name],
            using: provider, password: nil,
            engineVersion: session.resolveEngineVersion(profile.kind)
        )
        let url = session.artifactURL(in: session.library.directory(for: set), database: name, provider: provider)
        let artifact = DatabaseBackupArtifact(engine: engine, database: name, fileURL: url)
        guard artifact.hasContent else {
            throw DatabaseError.connection("The backup of \(name) produced no data.")
        }
        return artifact
    }

    private func resolveEngine(_ requested: DatabaseEngine?) throws -> DatabaseEngine {
        if let requested {
            guard tools.isInstalled(requested) else {
                throw DatabaseError.connection("\(requested.rawValue) isn't installed in KTStack.")
            }
            return requested
        }
        guard let first = DatabaseEngine.allCases.first(where: { tools.isInstalled($0) }) else {
            throw DatabaseError.connection("No managed database engine is installed.")
        }
        return first
    }

    static func managedProfile(for engine: DatabaseEngine) -> ConnectionProfile {
        switch engine {
        case .mysql: .managedMySQL
        case .postgres: .managedPostgres
        case .mongodb: .managedMongo
        }
    }
}
