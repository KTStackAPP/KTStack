import Foundation
import Combine

/// Drives the Database section: holds the live driver for the selected connection plus the
/// selection chain (connection → database → table) and the current result. `@MainActor` so it only
/// ever publishes from the main actor; every driver call is `async` and returns `Sendable` values,
/// so results cross back from the NIO event loop without a data race (the driver never touches
/// `@Published` state itself).
///
/// A monotonic `generation` token guards against a slow in-flight result from a superseded
/// selection: rapidly switching connections/tables or re-running SQL discards the older result
/// instead of letting it clobber the newer state.
@MainActor
public final class DatabaseViewModel: ObservableObject {

    /// Live state of the selected connection. `failed` carries the typed `DatabaseError` so the view
    /// can route `engineNotInstalled`/`engineNotRunning` to the install/start flow rather than show a
    /// dead-end "connection refused".
    public enum Connection: Equatable {
        case idle
        case connecting
        case connected
        case failed(DatabaseError)
    }

    /// Where the current result came from. A single-table browse has a well-defined target table the
    /// row-edit phase keys edits off; an arbitrary query/JOIN does not, so it stays read-only.
    public enum ResultSource: Equatable {
        case none
        case table(database: String, table: String)
        case query
    }

    @Published public private(set) var connection: Connection = .idle
    @Published public private(set) var selectedProfile: ConnectionProfile?
    @Published public private(set) var databases: [DatabaseInfo] = []
    @Published public private(set) var selectedDatabase: String?
    @Published public private(set) var tables: [TableInfo] = []
    @Published public private(set) var selectedTable: TableInfo?
    @Published public private(set) var result: QueryResult?
    @Published public private(set) var resultError: String?
    @Published public private(set) var resultSource: ResultSource = .none
    // `internal(set)` so the row-CRUD extension (a separate file) can flip busy state + surface errors.
    @Published public internal(set) var isBusy = false
    @Published public private(set) var pageOffset = 0
    /// True while the latest table page came back full (== `pageSize`), so a next page may exist.
    @Published public private(set) var hasMorePages = false
    /// Introspected columns of the currently browsed table (drives PK-keyed edits + the row editor).
    /// Empty for a SQL-runner result.
    @Published public private(set) var currentColumns: [ColumnInfo] = []
    /// A destructive SQL statement awaiting explicit confirmation before it runs (set by `runSQL`).
    @Published public private(set) var pendingDangerousSQL: String?
    /// Last row-mutation failure, surfaced as an alert (distinct from `resultError`, which replaces
    /// the grid). Nil when there's nothing to show. `internal(set)` for the row-CRUD extension.
    @Published public internal(set) var editError: String?

    /// Rows per table page. Bounded default keeps an unbounded `SELECT *` from materializing a huge
    /// table in memory; pagination walks the rest.
    public var pageSize = 100

    /// A single-table browse result (vs a SQL-runner/JOIN result). Drives showing the row grid +
    /// pagination; editability additionally requires a usable key (`canEditRows`).
    public var isTableBrowse: Bool {
        if case .table = resultSource { return true }
        return false
    }

    /// The browsed table's primary-key columns — the key set edits build UPDATE/DELETE predicates from.
    public var primaryKeyColumns: [ColumnInfo] { currentColumns.primaryKeyColumns }

    /// True when the selected connection is opened read-only (server-enforced). Mirrored into the UI so
    /// edit affordances are hidden rather than offered and then rejected by the server.
    public var isReadOnlyConnection: Bool { selectedProfile?.readOnly ?? false }

    /// Why row editing is unavailable, or nil when it's allowed. Editing needs a writable (not
    /// read-only) connection, a single-table browse, AND a primary key to target exactly one row; a
    /// read-only connection, a SQL result, or a PK-less table is not editable.
    public var editDisabledReason: String? {
        if isReadOnlyConnection { return "This connection is read-only." }
        guard isTableBrowse else { return "Editing is only available when browsing a single table." }
        guard !primaryKeyColumns.isEmpty else {
            return "This table has no primary key, so rows can't be edited safely."
        }
        return nil
    }

    /// True when rows in the current result can be inserted/updated/deleted.
    public var canEditRows: Bool { editDisabledReason == nil }

    public typealias DriverFactory = @Sendable (ConnectionProfile, String?) -> RelationalDriver?

    private let makeDriver: DriverFactory
    private let passwordFor: @Sendable (ConnectionProfile) -> String?
    /// `private(set)` so the row-CRUD extension can read the live driver (only this file sets it).
    private(set) var driver: RelationalDriver?

    /// Bumped on every new top-level operation; an async continuation whose token no longer matches
    /// is stale and bails before publishing.
    private var generation = 0

    public init(makeDriver: @escaping DriverFactory = DatabaseViewModel.defaultDriver,
                passwordFor: @escaping @Sendable (ConnectionProfile) -> String? = DatabaseViewModel.defaultPassword) {
        self.makeDriver = makeDriver
        self.passwordFor = passwordFor
    }

    // MARK: - Connection

    /// Open `profile`, verify it serves queries, and load its databases. Resets the selection chain
    /// first so a previous connection's tree never lingers under a new one.
    public func select(profile: ConnectionProfile) async {
        let token = beginOperation()
        selectedProfile = profile
        databases = []; tables = []; selectedDatabase = nil; selectedTable = nil
        result = nil; resultError = nil; resultSource = .none; pageOffset = 0; hasMorePages = false
        connection = .connecting

        guard let driver = makeDriver(profile, passwordFor(profile)) else {
            connection = .failed(.connection("Unsupported engine: \(profile.kind.rawValue)"))
            isBusy = false
            return
        }
        self.driver = driver
        do {
            try await driver.ping()
            let dbs = try await driver.listDatabases()
            guard token == generation else { return }
            databases = dbs
            connection = .connected
        } catch {
            guard token == generation else { return }
            connection = .failed(Self.asDatabaseError(error))
        }
        if token == generation { isBusy = false }
    }

    // MARK: - Schema

    public func select(database: String) async {
        guard let driver else { return }
        let token = beginOperation()
        selectedDatabase = database
        tables = []; selectedTable = nil; result = nil; resultError = nil; resultSource = .none
        do {
            let loaded = try await driver.listTables(database: database)
            guard token == generation else { return }
            tables = loaded
        } catch {
            guard token == generation else { return }
            resultError = Self.asDatabaseError(error).message
        }
        if token == generation { isBusy = false }
    }

    public func select(table: TableInfo) async {
        guard let driver, let database = selectedDatabase else { return }
        selectedTable = table
        pageOffset = 0
        currentColumns = []
        let token = beginOperation()
        // Introspect columns (PK flags) so the first page can be edited; a stale selection bails
        // before loading the page so it can't supersede a newer one.
        do {
            let cols = try await driver.columns(database: database, table: table.name)
            guard token == generation else { return }
            currentColumns = cols
        } catch {
            guard token == generation else { return }
            currentColumns = []
        }
        await loadPage()
    }

    // MARK: - Pagination

    public func nextPage() async {
        guard hasMorePages else { return }
        pageOffset += pageSize
        await loadPage()
    }

    public func previousPage() async {
        guard pageOffset > 0 else { return }
        pageOffset = max(0, pageOffset - pageSize)
        await loadPage()
    }

    /// Internal so the row-CRUD extension can reload the page after a successful write.
    func loadPage() async {
        guard let driver, let database = selectedDatabase, let table = selectedTable else { return }
        let token = beginOperation()
        do {
            let page = try await driver.paginatedRows(
                database: database, table: table.name, limit: pageSize, offset: pageOffset)
            guard token == generation else { return }
            result = page
            resultError = nil
            resultSource = .table(database: database, table: table.name)
            hasMorePages = page.rowCount == pageSize
        } catch {
            guard token == generation else { return }
            result = nil
            resultError = Self.asDatabaseError(error).message
            resultSource = .none
        }
        if token == generation { isBusy = false }
    }

    // MARK: - SQL runner

    /// Run arbitrary SQL against the selected database. The result is read-only (`.query` source) —
    /// a JOIN/expression result has no single editable target table. A destructive statement
    /// (keyless DELETE/UPDATE, DROP/TRUNCATE) is held in `pendingDangerousSQL` for the UI to confirm;
    /// the caller re-invokes with `confirmed: true` to actually run it.
    public func runSQL(_ sql: String, confirmed: Bool = false) async {
        guard let driver else { return }
        let trimmed = sql.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        if !confirmed, DestructiveGuard.evaluate(trimmed).isDestructive {
            pendingDangerousSQL = trimmed
            return
        }
        pendingDangerousSQL = nil
        let token = beginOperation()
        do {
            let r = try await driver.query(trimmed, database: selectedDatabase)
            guard token == generation else { return }
            result = r
            resultError = nil
            resultSource = .query
            hasMorePages = false
        } catch {
            guard token == generation else { return }
            result = nil
            resultError = Self.asDatabaseError(error).message
            resultSource = .none
        }
        if token == generation { isBusy = false }
    }

    /// Dismiss the pending destructive-SQL confirmation without running it.
    public func cancelDangerousSQL() { pendingDangerousSQL = nil }

    /// Clear the last edit error after the UI has shown it.
    public func clearEditError() { editError = nil }

    // MARK: - Helpers

    private func beginOperation() -> Int {
        generation += 1
        isBusy = true
        return generation
    }

    /// Map any error to the typed surface. Internal so the row-CRUD extension reuses it.
    static func asDatabaseError(_ error: Error) -> DatabaseError {
        (error as? DatabaseError) ?? .connection(error.localizedDescription)
    }
}
