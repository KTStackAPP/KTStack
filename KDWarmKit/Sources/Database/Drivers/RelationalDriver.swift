import Foundation

/// The contract every relational engine (MySQL now; PostgreSQL/SQLite in a later phase) implements.
/// Built concretely now — the root `DatabaseDriver` protocol that also abstracts the document track
/// (Mongo) is deferred until that second consumer exists, so this isn't a premature two-tier split.
///
/// Concurrency boundary (the NIO↔MainActor contract): every method is `async`, resolves its NIO
/// futures internally, and returns only `Sendable` values. A driver never touches `@Published` UI
/// state — the caller hops to `@MainActor` to publish. So a driver instance is safe to call from any
/// task, and its results cross back to the main actor without a data race.
public protocol RelationalDriver: Sendable {
    /// The engine this driver speaks, for dialect/registry branching.
    var kind: DatabaseKind { get }

    /// Open a connection and verify it can serve queries. Throws a typed `DatabaseError`
    /// (`engineNotInstalled`/`engineNotRunning`/`authenticationFailed`/…), never an opaque one.
    func ping() async throws

    /// Catalogs (MySQL "databases", PostgreSQL "schemas") visible to the connection's user.
    func listDatabases() async throws -> [DatabaseInfo]

    /// Base tables + views in a catalog.
    func listTables(database: String) async throws -> [TableInfo]

    /// Introspected columns for a table, including the per-column primary-key flag the row-edit phase
    /// keys UPDATEs on. Engine-catalog query — lives here, not in `SQLDialect`.
    func columns(database: String, table: String) async throws -> [ColumnInfo]

    /// Run arbitrary SQL and map the result into the typed `QueryResult`. Columns are preserved even
    /// when zero rows come back.
    func query(_ sql: String, database: String?) async throws -> QueryResult

    /// One page of a table's rows, composed via the engine's `SQLDialect` (LIMIT/OFFSET).
    func paginatedRows(database: String, table: String, limit: Int, offset: Int) async throws -> QueryResult
}
