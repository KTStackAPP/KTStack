import Combine
import Foundation
import KTPlatformContracts

@MainActor
public final class DatabaseV2ViewModel: ObservableObject {
    public enum ConnectionState: Equatable {
        case idle
        case connecting
        case connected
        case failed(String)
    }

    @Published public internal(set) var connectionState: ConnectionState = .idle
    public var isConnected: Bool {
        if case .connected = connectionState { return true }
        return false
    }
    @Published public private(set) var databases: [DatabaseInfo] = []
    @Published public private(set) var tables: [TableInfo] = []
    @Published public private(set) var selectedDatabase: String?
    @Published public private(set) var selectedTable: TableInfo?

    @Published public private(set) var rows: QueryResult?
    @Published public private(set) var pageOffset: Int = 0
    // Số dòng tuyệt đối của hàng đầu cửa sổ trượt; số dòng hiển thị = windowStart + index + 1.
    @Published public private(set) var windowStart: Int = 0
    @Published public private(set) var hasMore: Bool = false
    @Published public internal(set) var isSuspended: Bool = false
    @Published public private(set) var isLoadingRows: Bool = false
    @Published public private(set) var isLoadingStructure: Bool = false

    @Published public private(set) var columns: [ColumnInfo] = []
    @Published public private(set) var indexes: [IndexInfo] = []
    @Published public private(set) var foreignKeys: [ForeignKeyRelation] = []
    @Published public private(set) var checks: [CheckConstraintInfo] = []
    @Published public private(set) var diagramColumns: [String: [ColumnInfo]] = [:]
    @Published public private(set) var isLoadingDiagram: Bool = false
    @Published public private(set) var diagramLoaded: Bool = false

    @Published public private(set) var loadError: String?
    @Published public internal(set) var editError: String?
    @Published public internal(set) var ddlError: String?
    @Published public internal(set) var isDDLBusy: Bool = false
    @Published public internal(set) var createTableDDL: String?
    @Published public internal(set) var ddlPreview: DDLPreview?

    @Published public internal(set) var pendingChangeCount: Int = 0
    @Published public internal(set) var canUndoStaged: Bool = false
    @Published public internal(set) var canRedoStaged: Bool = false
    @Published public internal(set) var isCommitting: Bool = false
    @Published public internal(set) var cellEditor: V2CellEditorContext?
    @Published public internal(set) var insertDraft: [String: CellEdit]?
    @Published public internal(set) var navStack: [FKNavEntry] = []
    @Published public internal(set) var navIndex: Int = -1
    // ORDER BY của browse hiện tại; đọc trong fetchRows nên phân trang giữ nguyên sắp xếp.
    @Published public internal(set) var browseSort: SortSpec?

    var staged: StagedTableEditor?

    // Bắn sau DDL apply thành công để workspace bỏ cache schema và nạp lại sidebar.
    var onSchemaChanged: ((UUID, String) -> Void)?

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
    // Giữ profile để resume sau khi tab idle ngắt driver (suspend giữ nguyên rows/staged).
    private(set) var activeProfile: ConnectionProfile?
    private(set) var connectionLabel: String?
    private(set) var connectionReadOnly = false
    @Published public private(set) var connectionKind: DatabaseKind?
    @Published public internal(set) var capabilities: DriverCapabilities = .none

    // Pill trạng thái: phiên bản engine (SELECT VERSION()), độ trễ đo lúc ping, ước lượng số dòng lười.
    @Published public internal(set) var serverVersion: String?
    @Published public internal(set) var latencyMs: Int?
    @Published public internal(set) var rowCountEstimate: Int?
    @Published public internal(set) var isCountingRows: Bool = false
    var rowCountTask: Task<Void, Never>?
    public var connectionIsReadOnly: Bool { connectionReadOnly }

    public var schemaName: String {
        selectedDatabase ?? ""
    }

    public let pageSize: Int = 200
    // Trần cửa sổ trượt: 5 trang, cắt đầu khi vượt để RAM 100k dòng đã cuộn nằm dưới 140 MB.
    public var maxWindowRows: Int { pageSize * 5 }

    public var schemaCatalog: SchemaCatalog {
        SchemaCatalog(
            tables: tables.map(\.name),
            columnsByTable: diagramColumns.mapValues { $0.map(\.name) },
            detailedColumnsByTable: diagramColumns,
            relations: foreignKeys
        )
    }

    let makeDriver: DatabaseViewModel.DriverFactory
    let passwordFor: @Sendable (ConnectionProfile) -> String?
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
        isSuspended = false
        activeProfile = profile
        connectionProfileID = profile.id.uuidString
        connectionLabel = profile.name
        connectionReadOnly = profile.readOnly
        connectionKind = profile.kind
        capabilities = .none
        serverVersion = nil
        latencyMs = nil
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
            let pingStart = DispatchTime.now().uptimeNanoseconds
            try await newDriver.ping()
            let elapsed = DispatchTime.now().uptimeNanoseconds - pingStart
            guard token == generation else { return }
            latencyMs = Int((Double(elapsed) / 1_000_000).rounded())
            let dbs = try await newDriver.listDatabases()
            guard token == generation else { return }
            try? await newDriver.openSession()
            databases = dbs
            capabilities = newDriver.capabilities
            connectionState = .connected
            fetchServerVersion(driver: newDriver, token: token)
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
        isSuspended = false
        activeProfile = nil
        windowStart = 0
        connectionState = .idle
        capabilities = .none
        serverVersion = nil
        latencyMs = nil
        rowCountTask?.cancel()
        rowCountTask = nil
        rowCountEstimate = nil
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
    public func reloadDatabases() async {
        guard let driver else { return }
        if let dbs = try? await driver.listDatabases() {
            databases = dbs
        }
    }

    public func select(database: String) async {
        await ensureConnected()
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
        guard let driver else { return }
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
        windowStart = 0
        hasMore = false
        columns = []
        indexes = []
        checks = []
        resetStagingUnlessEditing(entry.table)
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
        await ensureConnected()
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
            windowStart = 0
            pageOffset = result.rowCount
            hasMore = result.rowCount == pageSize
            refreshRowCount()
        } catch {
            guard token == generation else { return }
            loadError = error.localizedDescription
        }
        isLoadingRows = false
    }

    public func fetchMore() async {
        await ensureConnected()
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
                var merged = existing.rows + result.rows
                if merged.count > maxWindowRows {
                    let overflow = merged.count - maxWindowRows
                    merged.removeFirst(overflow)
                    windowStart += overflow
                }
                rows = QueryResult(
                    columns: existing.columns,
                    rows: merged,
                    truncated: result.truncated,
                    estimatedTotal: result.estimatedTotal
                )
            } else {
                rows = result
                windowStart = pageOffset
            }
            pageOffset += result.rowCount
            hasMore = result.rowCount == pageSize
        } catch {
            guard token == generation else { return }
            loadError = error.localizedDescription
        }
        isLoadingRows = false
    }

    /// Cuộn lên đầu cửa sổ: tải trang trước (offset = windowStart - pageSize), nối vào đầu, cắt bớt
    /// đuôi nếu vượt trần. Giữ invariant pageOffset == windowStart + rows.count.
    public func fetchPrevious() async {
        await ensureConnected()
        let token = generation
        guard let driver, let database = selectedDatabase, let table = selectedTable,
              windowStart > 0, !isLoadingRows, let existing = rows else { return }
        let offset = max(0, windowStart - pageSize)
        let limit = windowStart - offset
        guard limit > 0 else { return }
        isLoadingRows = true
        do {
            let result = try await fetchRows(
                driver: driver, database: database, table: table.name, limit: limit, offset: offset
            )
            guard token == generation else { return }
            var merged = result.rows + existing.rows
            if merged.count > maxWindowRows {
                let overflow = merged.count - maxWindowRows
                merged.removeLast(overflow)
                pageOffset -= overflow
                hasMore = true
            }
            rows = QueryResult(
                columns: existing.columns,
                rows: merged,
                truncated: existing.truncated,
                estimatedTotal: existing.estimatedTotal
            )
            windowStart = offset
        } catch {
            guard token == generation else { return }
            loadError = error.localizedDescription
        }
        isLoadingRows = false
    }

    func reloadLoaded() async {
        await ensureConnected()
        let token = generation
        guard let driver, let database = selectedDatabase, let table = selectedTable else { return }
        // Chỉ nạp lại cửa sổ hiện tại, không nối lại toàn bộ đã cuộn (có thể tới 100k dòng).
        let limit = max(rows?.rowCount ?? pageSize, pageSize)
        do {
            let result = try await fetchRows(
                driver: driver, database: database, table: table.name, limit: limit, offset: windowStart
            )
            guard token == generation else { return }
            rows = result
            pageOffset = windowStart + result.rowCount
            hasMore = result.rowCount == limit
        } catch {
            guard token == generation else { return }
            loadError = error.localizedDescription
        }
    }

    public func loadStructure(table: TableInfo, token: Int? = nil) async {
        await ensureConnected()
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
            let checkList = try await driver.checkConstraints(database: database, table: table.name)
            guard token == generation else { return }
            columns = cols
            indexes = idxs
            foreignKeys = fks
            checks = checkList
            rebuildStagedEditor()
        } catch {
            guard token == generation else { return }
            loadError = error.localizedDescription
        }
        isLoadingStructure = false
    }

    public func loadDiagram() async {
        guard !diagramLoaded else { return }
        await ensureConnected()
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
        windowStart = 0
        hasMore = false
        isLoadingRows = false
        isLoadingStructure = false
        columns = []
        indexes = []
        checks = []
        loadError = nil
        editError = nil
        ddlError = nil
        staged = nil
        pendingChangeCount = 0
        canUndoStaged = false
        canRedoStaged = false
        isCommitting = false
        cellEditor = nil
        insertDraft = nil
        browseSort = nil
        navStack = []
        navIndex = -1
        rowCountTask?.cancel()
        rowCountTask = nil
        rowCountEstimate = nil
    }

    func reloadAfterDDL() async {
        if let database = selectedDatabase {
            tables = await (try? driver?.listTables(database: database)) ?? tables
        }
        if let table = selectedTable {
            await loadStructure(table: table)
        }
        if let profileID = activeProfile?.id, let database = selectedDatabase {
            onSchemaChanged?(profileID, database)
        }
    }
}
