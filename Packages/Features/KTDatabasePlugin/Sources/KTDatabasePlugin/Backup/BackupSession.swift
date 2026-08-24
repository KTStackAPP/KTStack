import Foundation
import KTPlatformContracts
import KTStackCore

public struct BackupSession: Sendable {
    public let library: BackupLibrary
    public let resolveEngineVersion: @Sendable (DatabaseKind) -> String?
    let tools: any DatabaseToolsProviding

    public init(
        library: BackupLibrary = BackupLibrary(),
        tools: any DatabaseToolsProviding,
        resolveEngineVersion: @escaping @Sendable (DatabaseKind) -> String? = { _ in nil }
    ) {
        self.library = library
        self.tools = tools
        self.resolveEngineVersion = resolveEngineVersion
    }

    public static func managed(
        tools: any DatabaseToolsProviding,
        paths: AppSupportPaths = AppSupportPaths()
    ) -> BackupSession {
        BackupSession(
            library: BackupLibrary(paths: paths),
            tools: tools,
            resolveEngineVersion: { kind in kind.engine.flatMap(tools.activeVersion) }
        )
    }

    public func provider(for kind: DatabaseKind) -> BackupProviderResult {
        BackupProviderFactory.make(for: kind, tools: tools)
    }

    public func create(
        profile: ConnectionProfile,
        password: String?,
        databases: [String]
    ) async throws -> BackupSet {
        guard let provider = providerOrThrow(profile.kind) else {
            throw DatabaseError.connection("Backup isn't available for \(profile.kind.rawValue).")
        }
        return try await library.create(
            kind: profile.kind, profile: profile, databases: databases,
            using: provider, password: password,
            engineVersion: resolveEngineVersion(profile.kind)
        )
    }

    public func restore(
        set: BackupSet,
        database: String,
        profile: ConnectionProfile,
        password: String?,
        target: RestoreTarget
    ) async throws {
        guard set.kind == profile.kind else {
            throw DatabaseError.connection(
                "Backup engine (\(set.kind.rawValue)) doesn't match the active connection (\(profile.kind.rawValue))."
            )
        }
        try requireCompatibleVersion(set: set, kind: profile.kind)
        guard let provider = providerOrThrow(profile.kind) else {
            throw DatabaseError.connection("Restore isn't available for \(profile.kind.rawValue).")
        }
        let artifact = artifactURL(
            in: library.directory(for: set),
            database: database,
            provider: provider
        )
        try await provider.restore(
            profile: profile,
            password: password,
            from: artifact,
            into: target
        )
    }

    public func artifactURL(in setDir: URL, database: String, provider: BackupProvider) -> URL {
        setDir.appendingPathComponent(provider.artifactName(for: database))
    }

    public func delete(_ set: BackupSet) throws {
        try library.delete(set)
    }

    public func exportSet(_ set: BackupSet, to destination: URL) throws {
        try library.export(set, to: destination)
    }

    private func providerOrThrow(_ kind: DatabaseKind) -> BackupProvider? {
        if case let .available(provider) = BackupProviderFactory.make(for: kind, tools: tools) { return provider }
        return nil
    }

    private func requireCompatibleVersion(set: BackupSet, kind: DatabaseKind) throws {
        guard let stored = set.engineVersion,
              let current = resolveEngineVersion(kind) else { return }
        guard Self.majorVersion(stored) != Self.majorVersion(current) else { return }
        throw DatabaseError.connection(
            "This backup was made on \(kind.rawValue) \(stored); the installed engine is \(current). "
                + "Restore aborted before any destructive step."
        )
    }

    static func majorVersion(_ version: String) -> String {
        version.split(whereSeparator: { $0 == "." || $0 == "-" }).first.map(String.init) ?? version
    }

    public static func userDatabaseNames(_ names: [String], for kind: DatabaseKind) -> [String] {
        let system: Set<String> = switch kind {
        case .mysql: ["information_schema", "performance_schema", "mysql", "sys"]
        case .postgres: ["template0", "template1"]
        case .mongodb: ["admin", "local", "config"]
        case .sqlite: []
        }
        return names.filter { !system.contains($0.lowercased()) }
    }
}
