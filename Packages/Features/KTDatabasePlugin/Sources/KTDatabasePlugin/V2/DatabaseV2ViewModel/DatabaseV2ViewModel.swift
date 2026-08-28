import Combine
import Foundation
import KTPlatformContracts

@MainActor
public final class DatabaseV2ViewModel: ObservableObject {
    public enum ConnectionState {
        case idle
        case connecting
        case connected
        case failed(String)
    }

    @Published public private(set) var connectionState: ConnectionState = .idle
    @Published public private(set) var databases: [DatabaseInfo] = []
    @Published public private(set) var tables: [TableInfo] = []
    @Published public private(set) var selectedDatabase: String?
    @Published public private(set) var selectedTable: TableInfo?

    @Published public private(set) var rows: QueryResult?
    @Published public private(set) var pageOffset: Int = 0
    @Published public private(set) var hasMore: Bool = false
    @Published public private(set) var isLoadingRows: Bool = false
    @Published public private(set) var isLoadingStructure: Bool = false

    @Published public private(set) var columns: [ColumnInfo] = []
    @Published public private(set) var indexes: [IndexInfo] = []
    @Published public private(set) var foreignKeys: [ForeignKeyRelation] = []
    @Published public private(set) var diagramColumns: [String: [ColumnInfo]] = [:]
    @Published public private(set) var isLoadingDiagram: Bool = false
    @Published public private(set) var diagramLoaded: Bool = false

    @Published public private(set) var loadError: String?
    @Published public internal(set) var editError: String?
    @Published public internal(set) var ddlError: String?
    @Published public internal(set) var isDDLBusy: Bool = false

    @Published public internal(set) var pendingChangeCount: Int = 0
    @Published public internal(set) var canUndoStaged: Bool = false
    @Published public internal(set) var canRedoStaged: Bool = false
    @Published public internal(set) var isCommitting: Bool = false
    @Published public internal(set) var cellEditor: V2CellEditorContext?
    @Published public internal(set) var navStack: [FKNavEntry] = []
    @Published public internal(set) var navIndex: Int = -1

    var staged: StagedTableEditor?

    @Published public var queryTabs: [V2QueryTab]
    @Published public internal(set) var activeQueryTabID: UUID?
    @Published public internal(set) var parameterPrompt: QueryParameterPrompt?
    @Published public internal(set) var formatTrigger = 0
    @Published public internal(set) var queryHistory: [QueryHistoryEntry] = []
    @Published public internal(set) var favorites: [QueryFavorite] = []
    @Published public internal(set) var activeQuerySheet: V2QuerySheet?
    @Published public internal(set) var destructivePrompt: DestructivePrompt?
    @Published public internal(set) var explainSheet: ExplainResult?
    public private(set) var connectionProfileID: String?
    private(set) var connectionLabel: String?
    private(set) var connectionReadOnly = false
    @Published public private(set) var connectionKind: DatabaseKind?
    @Published public private(set) var capabilities: DriverCapabilities = .none

    public var schemaName: String {
        selectedDatabase ?? ""
    }

    public let pageSize: Int = 200

    public var schemaCatalog: SchemaCatalog {
        SchemaCatalog(
            tables: tables.map(\.name),
            columnsByTable: diagramColumns.mapValues { $0.map(\.name) },
            detailedColumnsByTable: diagramColumns,
            relations: foreignKeys
        )
    }

    private let makeDriver: DatabaseViewModel.DriverFactory
    private let passwordFor: @Sendable (ConnectionProfile) -> String?
    let presetStore: FilterPresetStore?
    let historyStore: QueryHistoryStore
    let favoriteStore: QueryFavoriteStore
    var driver: RelationalDriver?
    var generation = 0

    public init(
        tools: any DatabaseToolsProviding,
        presetStore: FilterPresetStore? = nil,
        historyStore: QueryHistoryStore = QueryHistoryStore(),
        favoriteStore: QueryFavoriteStore = QueryFavoriteStore(),
        makeDriver: DatabaseViewModel.DriverFactory? = nil,
        passwordFor: @escaping @Sendable (ConnectionProfile) -> String? = DatabaseViewModel.defaultPassword
    ) {
        self.makeDriver = makeDriver ?? DatabaseViewModel.defaultDriver(tools: tools)
        self.passwordFor = passwordFor
        self.presetStore = presetStore
        self.historyStore = historyStore
        self.favoriteStore = favoriteStore
        let initialTab = V2QueryTab(title: "Query 1")
        queryTabs = [initialTab]
        activeQueryTabID = initialTab.id
        queryHistory = historyStore.entries()
        favorites = favoriteStore.entries()
    }

    public func connect(profile: ConnectionProfile) async {
        generation += 1
        let token = generation
        let previousDriver = driver
        driver = nil
        connectionState = .connecting
        connectionProfileID = profile.id.uuidString
        connectionLabel = profile.name
        connectionReadOnly = profile.readOnly
        connectionKind = profile.kind
        capabilities = .none
        databases = []
        tables = []
        selectedDatabase = nil
        selectedTable = nil
        resetTableState()
        foreignKeys = []
        diagramColumns = [:]
        diagramLoaded = false
        await previousDriver?.closeSession()

        guard token == generation else { return }

        guard let newDriver = makeDriver(profile, passwordFor(profile)) else {
            connectionState = .failed("Unsupported engine: \(profile.kind.rawValue)")
            return
        }
        driver = newDriver
        do {
            try await newDriver.ping()
            let dbs = try await newDriver.listDatabases()
            guard token == generation else { return }
            try? await newDriver.openSession()
            databases = dbs
            capabilities = newDriver.capabilities
            connectionState = .connected
            if let firstDatabase = dbs.first {
                await select(database: firstDatabase.name)
            }
        } catch {
            guard token == generation else { return }
            connectionState = .failed(error.localizedDescription)
            driver = nil
        }
    }

    public func disconnect() async {
        generation += 1
        let oldDriver = driver
        driver = nil
        connectionState = .idle
        capabilities = .none
        databases = []
        tables = []
        selectedDatabase = nil
        selectedTable = nil
        resetTableState()
        foreignKeys = []
        diagramColumns = [:]
        diagramLoaded = false
        await oldDriver?.closeSession()
    }

    public func select(database: String) async {
        guard let driver else { return }
        generation += 1
        let token = generation
        selectedDatabase = database
        tables = []
        selectedTable = nil
        resetTableState()
        foreignKeys = []
        diagramColumns = [:]
        diagramLoaded = false
        loadError = nil
        do {
            let result = try await driver.listTables(database: database)
            guard token == generation else { return }
            tables = result
        } catch {
            guard token == generation else { return }
            loadError = error.localizedDescription
        }
    }

    public func select(table: TableInfo) {
        generation += 1
        let token = generation
        selectedTable = table
        resetTableState()
        navStack = [FKNavEntry(table: table, filters: [])]
        navIndex = 0
        isLoadingRows = true
        isLoadingStructure = true
        Task {
            await loadRows(table: table, token: token)
            await loadStructure(table: table, token: token)
        }
    }

    // Tải bước lịch sử FK hiện tại (navIndex đã trỏ đúng); light reset, giữ nguyên navStack.
    func loadNavEntry() {
        guard navStack.indices.contains(navIndex) else { return }
        let entry = navStack[navIndex]
        generation += 1
        let token = generation
        selectedTable = entry.table
        rows = nil
        pageOffset = 0
        hasMore = false
        columns = []
        indexes = []
        staged = nil
        pendingChangeCount = 0
        canUndoStaged = false
        canRedoStaged = false
        editError = nil
        loadError = nil
        cellEditor = nil
        isLoadingRows = true
        isLoadingStructure = true
        Task {
            await loadRows(table: entry.table, token: token)
            await loadStructure(table: entry.table, token: token)
        }
    }

    public func loadRows(table: TableInfo, token: Int? = nil) async {
        let token = token ?? generation
        guard let driver, let database = selectedDatabase else {
            isLoadingRows = false
            return
        }
        isLoadingRows = true
        loadError = nil
        do {
            let result = try await fetchRows(
                driver: driver, database: database, table: table.name, limit: pageSize, offset: 0
            )
            guard token == generation else { return }
            rows = result
            pageOffset = result.rowCount
            hasMore = result.rowCount == pageSize
        } catch {
            guard token == generation else { return }
            loadError = error.localizedDescription
        }
        isLoadingRows = false
    }

    public func fetchMore() async {
        let token = generation
        guard let driver, let database = selectedDatabase, let table = selectedTable,
              hasMore, !isLoadingRows else { return }
        isLoadingRows = true
        do {
            let result = try await fetchRows(
                driver: driver, database: database, table: table.name, limit: pageSize, offset: pageOffset
            )
            guard token == generation else { return }
            if let existing = rows {
                rows = QueryResult(
                    columns: existing.columns,
                    rows: existing.rows + result.rows,
                    truncated: result.truncated,
                    estimatedTotal: result.estimatedTotal
                )
            } else {
                rows = result
            }
            pageOffset += result.rowCount
            hasMore = result.rowCount == pageSize
        } catch {
            guard token == generation else { return }
            loadError = error.localizedDescription
        }
        isLoadingRows = false
    }

    func reloadLoaded() async {
        let token = generation
        guard let driver, let database = selectedDatabase, let table = selectedTable else { return }
        let limit = max(pageOffset, pageSize)
        do {
            let result = try await fetchRows(
                driver: driver, database: database, table: table.name, limit: limit, offset: 0
            )
            guard token == generation else { return }
            rows = result
            pageOffset = result.rowCount
            hasMore = result.rowCount == limit
        } catch {
            guard token == generation else { return }
            loadError = error.localizedDescription
        }
    }

    public func loadStructure(table: TableInfo, token: Int? = nil) async {
        let token = token ?? generation
        guard let driver, let database = selectedDatabase else {
            isLoadingStructure = false
            return
        }
        do {
            let cols = try await driver.columns(database: database, table: table.name)
            guard token == generation else { return }
            let idxs = try await driver.indexes(database: database, table: table.name)
            guard token == generation else { return }
            let fks = try await driver.foreignKeys(database: database)
            guard token == generation else { return }
            columns = cols
            indexes = idxs
            foreignKeys = fks
            rebuildStagedEditor()
        } catch {
            guard token == generation else { return }
            loadError = error.localizedDescription
        }
        isLoadingStructure = false
    }

    public func loadDiagram() async {
        guard !diagramLoaded else { return }
        let token = generation
        guard let driver, let database = selectedDatabase else { return }
        isLoadingDiagram = true
        loadError = nil
        do {
            let cols = try await driver.allColumnsDetailed(database: database)
            guard token == generation else { isLoadingDiagram = false; return }
            let fks = try await driver.foreignKeys(database: database)
            guard token == generation else { isLoadingDiagram = false; return }
            diagramColumns = cols
            foreignKeys = fks
            diagramLoaded = true
        } catch {
            guard token == generation else { isLoadingDiagram = false; return }
            loadError = error.localizedDescription
        }
        isLoadingDiagram = false
    }

    private func resetTableState() {
        rows = nil
        pageOffset = 0
        hasMore = false
        isLoadingRows = false
        isLoadingStructure = false
        columns = []
        indexes = []
        loadError = nil
        editError = nil
        ddlError = nil
        staged = nil
        pendingChangeCount = 0
        canUndoStaged = false
        canRedoStaged = false
        isCommitting = false
        cellEditor = nil
        navStack = []
        navIndex = -1
    }

    func reloadAfterDDL() async {
        if let database = selectedDatabase {
            tables = await (try? driver?.listTables(database: database)) ?? tables
        }
        if let table = selectedTable {
            await loadStructure(table: table)
        }
    }
}
