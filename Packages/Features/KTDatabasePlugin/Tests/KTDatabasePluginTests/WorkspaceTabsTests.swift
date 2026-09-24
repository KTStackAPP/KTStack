import Combine
import KTStackCore
import XCTest
@testable import KTDatabasePlugin

private final class TabDriver: RelationalDriver, @unchecked Sendable {
    let kind: DatabaseKind = .mysql
    var capabilities: DriverCapabilities { DriverCapabilities() }
    private let lock = NSLock()
    private var _close = 0
    var closeCount: Int { lock.withLock { _close } }

    func ping() async throws {}
    func listDatabases() async throws -> [DatabaseInfo] { [DatabaseInfo(name: "db")] }
    func listTables(database _: String) async throws -> [TableInfo] {
        [TableInfo(name: "t"), TableInfo(name: "u")]
    }
    func columns(database _: String, table _: String) async throws -> [ColumnInfo] {
        [
            ColumnInfo(name: "id", dataType: "int", isNullable: false, isPrimaryKey: true),
            ColumnInfo(name: "name", dataType: "varchar", isNullable: true, isPrimaryKey: false),
        ]
    }
    func allColumns(database _: String) async throws -> [String: [String]] { [:] }
    func allColumnsDetailed(database _: String) async throws -> [String: [ColumnInfo]] { [:] }
    func indexes(database _: String, table _: String) async throws -> [IndexInfo] { [] }
    func foreignKeys(database _: String) async throws -> [ForeignKeyRelation] { [] }
    func query(_: String, database _: String?) async throws -> QueryResult {
        QueryResult(columns: [ColumnMeta(name: "id")], rows: [])
    }
    func paginatedRows(database _: String, table _: String, limit: Int, offset: Int) async throws -> QueryResult {
        let count = max(0, min(limit, 10 - offset))
        let rows = (0..<count).map { [Cell.int(Int64(offset + $0)), Cell.text("n")] }
        return QueryResult(columns: [ColumnMeta(name: "id"), ColumnMeta(name: "name")], rows: rows)
    }
    func openSession() async throws {}
    func closeSession() async { lock.withLock { _close += 1 } }
    func runSelect(_: DMLStatement, database _: String?) async throws -> QueryResult {
        QueryResult(columns: [ColumnMeta(name: "id")], rows: [])
    }
    func insert(database _: String, table _: String, values _: [ColumnValue]) async throws {}
    func update(database _: String, table _: String, values _: [ColumnValue], key _: [ColumnValue]) async throws {}
    func delete(database _: String, table _: String, key _: [ColumnValue]) async throws {}
}

@MainActor
final class WorkspaceTabsTests: XCTestCase {
    private func tempURL() -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    }

    private func makeStore(idle: TimeInterval = 300) -> WorkspaceStore {
        let connections = ConnectionStore(storeURL: tempURL().appendingPathComponent("connections.json"))
        return WorkspaceStore(
            connectionStore: connections,
            reachability: ServerReachabilityService(),
            recentStore: RecentObjectStore(storeURL: tempURL().appendingPathComponent("recent.json")),
            objectLoader: { _ in [] },
            makeViewModel: {
                DatabaseV2ViewModel(
                    tools: FakeDatabaseTools(),
                    historyStore: QueryHistoryStore(paths: AppSupportPaths(root: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString))),
                    favoriteStore: QueryFavoriteStore(paths: AppSupportPaths(root: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString))),
                    makeDriver: { _, _ in TabDriver() },
                    passwordFor: { _ in nil }
                )
            },
            tabIdleInterval: idle
        )
    }

    private var profileID: UUID { ConnectionProfile.managedMySQL.id }

    private func waitFor(_ predicate: @escaping () -> Bool, timeoutMs: Int = 2000) async {
        for _ in 0..<(timeoutMs / 5) where !predicate() {
            try? await Task.sleep(nanoseconds: 5_000_000)
        }
    }

    func testOpenTableCreatesOneTab() async {
        let store = makeStore()
        store.openTable(TableInfo(name: "t"), profileID: profileID, database: "db", forceNewTab: false)
        XCTAssertEqual(store.tabs.count, 1)
        XCTAssertEqual(store.activeTabID, store.tabs.first?.id)
        await waitFor { store.tabs.first?.vm.rows != nil }
        XCTAssertNotNil(store.tabs.first?.vm.rows)
    }

    func testOpenSameTableActivatesExisting() async {
        let store = makeStore()
        store.openTable(TableInfo(name: "t"), profileID: profileID, database: "db", forceNewTab: false)
        await waitFor { store.tabs.first?.vm.rows != nil }
        let first = store.activeTabID
        store.openTable(TableInfo(name: "t"), profileID: profileID, database: "db", forceNewTab: true)
        XCTAssertEqual(store.tabs.count, 1)
        XCTAssertEqual(store.activeTabID, first)
    }

    // Single-click vào tab sạch preview đè lên tab hiện tại, không mở tab mới.
    func testSingleClickCleanTabPreviewsInPlace() async {
        let store = makeStore()
        store.openTable(TableInfo(name: "t"), profileID: profileID, database: "db", forceNewTab: false)
        await waitFor { store.tabs.first?.vm.rows != nil }
        let firstID = store.activeTabID
        store.openTable(TableInfo(name: "u"), profileID: profileID, database: "db", forceNewTab: false)
        XCTAssertEqual(store.tabs.count, 1)
        XCTAssertEqual(store.activeTabID, firstID)
        XCTAssertEqual(store.activeSession?.kind.title, "u")
    }

    // Double-click (forceNewTab) mở tab mới cho bảng khác.
    func testDoubleClickOpensSecondTab() async {
        let store = makeStore()
        store.openTable(TableInfo(name: "t"), profileID: profileID, database: "db", forceNewTab: false)
        await waitFor { store.tabs.first?.vm.rows != nil }
        store.openTable(TableInfo(name: "u"), profileID: profileID, database: "db", forceNewTab: true)
        XCTAssertEqual(store.tabs.count, 2)
    }

    // Tab đang staged không bị preview đè: single-click bảng khác mở tab mới.
    func testStagedTabIsNotPreviewedOver() async {
        let store = makeStore()
        store.openTable(TableInfo(name: "t"), profileID: profileID, database: "db", forceNewTab: false)
        let session = store.tabs.first!
        await waitFor { session.vm.rows != nil && !session.vm.isLoadingStructure }
        session.vm.stageCellEdit(row: 0, column: 1, newValue: "edited")
        store.openTable(TableInfo(name: "u"), profileID: profileID, database: "db", forceNewTab: false)
        XCTAssertEqual(store.tabs.count, 2)
    }

    func testCloseCleanTabRemovesIt() async {
        let store = makeStore()
        store.openTable(TableInfo(name: "t"), profileID: profileID, database: "db", forceNewTab: false)
        let id = store.activeTabID!
        XCTAssertEqual(store.closeTab(id), .closed)
        XCTAssertTrue(store.tabs.isEmpty)
        XCTAssertNil(store.activeTabID)
    }

    func testCloseStagedTabNeedsConfirmation() async {
        let store = makeStore()
        store.openTable(TableInfo(name: "t"), profileID: profileID, database: "db", forceNewTab: false)
        let session = store.tabs.first!
        await waitFor { session.vm.rows != nil && !session.vm.isLoadingStructure }
        session.vm.stageCellEdit(row: 0, column: 1, newValue: "edited")
        XCTAssertEqual(store.pendingChangeTotal, 1)
        XCTAssertEqual(store.closeTab(session.id), .needsConfirmation(1))
        XCTAssertEqual(store.tabs.count, 1)
        XCTAssertEqual(store.closeTab(session.id, force: true), .closed)
        XCTAssertTrue(store.tabs.isEmpty)
    }

    func testIdleSuspendsConnection() async {
        let store = makeStore(idle: 0.15)
        store.openTable(TableInfo(name: "t"), profileID: profileID, database: "db", forceNewTab: false)
        let session = store.tabs.first!
        await waitFor { session.vm.connectionState.isConnected }
        await waitFor(timeoutMs: 2000) { session.vm.isSuspended }
        XCTAssertTrue(session.vm.isSuspended)
        XCTAssertNil(session.vm.driver)
    }

    func testPendingEditsInAnyWorkspaceVetoQuit() async {
        let store = makeStore()
        let workspace = WorkspaceSession(
            store: store, shell: store.makeViewModel!(), tools: FakeDatabaseTools(), paths: AppSupportPaths(root: tempURL())
        )
        store.openTable(TableInfo(name: "t"), profileID: profileID, database: "db", forceNewTab: false)
        let tab = store.tabs.first!
        await waitFor { tab.vm.rows != nil && !tab.vm.isLoadingStructure }
        tab.vm.stageCellEdit(row: 0, column: 1, newValue: "edited")

        XCTAssertTrue(WorkspaceSessionRegistry.shared.sessions.contains { $0 === workspace })
        XCTAssertGreaterThanOrEqual(WorkspaceSessionRegistry.shared.pendingChangeTotal, 1)
        XCTAssertEqual(KTDatabasePlugin.pendingWorkDescription(pending: 1), "1 pending database change in open tabs will be discarded.")
        XCTAssertNil(KTDatabasePlugin.pendingWorkDescription(pending: 0))
    }
}

private extension DatabaseV2ViewModel.ConnectionState {
    var isConnected: Bool {
        if case .connected = self { return true }
        return false
    }
}
