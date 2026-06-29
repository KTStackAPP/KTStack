import Foundation

/// Engine-agnostic orchestration the relational and document view-models share. Each VM keeps a
/// `BackupStatus` and the human-readable result; this struct picks the right provider, validates the
/// version-skew gate before any destructive step, and routes through `BackupLibrary`.
public struct BackupSession: Sendable {
    public let library: BackupLibrary
    public let resolveEngineVersion: @Sendable (DatabaseKind) -> String?

    public init(
        library: BackupLibrary = BackupLibrary(),
        resolveEngineVersion: @escaping @Sendable (DatabaseKind) -> String? = { _ in nil }
    ) {
        self.library = library
        self.resolveEngineVersion = resolveEngineVersion
    }

    /// Default wiring that resolves engine versions from the managed binary catalog so a restore
    /// refuses across mismatched major versions (e.g. archived `pg_dump -Fc` from PostgreSQL 16
    /// against an installed 17).
    public static func managed(paths: AppSupportPaths = AppSupportPaths()) -> BackupSession {
        let catalog = ServiceBinaryCatalog(paths: paths)
        return BackupSession(
            library: BackupLibrary(paths: paths),
            resolveEngineVersion: { kind in
                switch kind {
                case .mysql: catalog.installedVersion(.mysql)
                case .postgres: catalog.installedVersion(.postgres)
                case .mongodb: catalog.installedVersion(.mongodb)
                case .sqlite: nil
                }
            }
        )
    }

    public func provider(for kind: DatabaseKind) -> BackupProviderResult {
        BackupProviderFactory.make(for: kind)
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
        if case let .available(provider) = BackupProviderFactory.make(for: kind) { return provider }
        return nil
    }

    /// `pg_dump -Fc` archives aren't backward-compatible across major versions; refuse a restore when
    /// the engine major version doesn't match the one stamped at backup time. Major versions match
    /// when the leading numeric segment is equal (e.g. 17.10 ↔ 17.12 OK; 16 ↔ 17 not).
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

    /// Drop the engine's system schemas from a "back up all databases" enumeration. mysqldump
    /// refuses `information_schema` outright; Postgres templates aren't connectable; Mongo's
    /// `admin/local/config` carry server state that shouldn't be restored over a user DB. Each set
    /// is the documented system-database list for that engine — no heuristic guess.
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
