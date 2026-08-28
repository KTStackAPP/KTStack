import KTStackCore
import XCTest
@testable import KTDatabasePlugin

/// Engine-free checks for the query library: history recording, favorites round-trip, recall into a
/// new tab, and per-tab database routing.
@MainActor
final class V2QueryLibraryTests: XCTestCase {
    private final class DBRecordingDriver: RelationalDriver, @unchecked Sendable {
        let kind: DatabaseKind = .mysql
        private(set) var lastQueryDatabase: String?

        func ping() async throws {}
        func listDatabases() async throws -> [DatabaseInfo] { [DatabaseInfo(name: "app"), DatabaseInfo(name: "other")] }
        func listTables(database _: String) async throws -> [TableInfo] { [] }
        func columns(database _: String, table _: String) async throws -> [ColumnInfo] { [] }
        func indexes(database _: String, table _: String) async throws -> [IndexInfo] { [] }
        func foreignKeys(database _: String) async throws -> [ForeignKeyRelation] { [] }
        func allColumns(database _: String) async throws -> [String: [String]] { [:] }
        func allColumnsDetailed(database _: String) async throws -> [String: [ColumnInfo]] { [:] }
        func openSession() async throws {}
        func closeSession() async {}
        func runSelect(_ statement: DMLStatement, database _: String?) async throws -> QueryResult {
            QueryResult(columns: [ColumnMeta(name: "id")], rows: [[.int(1)]])
        }

        func insert(database _: String, table _: String, values _: [ColumnValue]) async throws {}
        func update(database _: String, table _: String, values _: [ColumnValue], key _: [ColumnValue]) async throws {}
        func delete(database _: String, table _: String, key _: [ColumnValue]) async throws {}
        func paginatedRows(database _: String, table _: String, limit _: Int, offset _: Int) async throws -> QueryResult {
            QueryResult(columns: [ColumnMeta(name: "id")], rows: [[.int(1)]])
        }

        func query(_ sql: String, database: String?) async throws -> QueryResult {
            lastQueryDatabase = database
            _ = sql
            return QueryResult(columns: [ColumnMeta(name: "id")], rows: [[.int(1)]])
        }
    }

    private func tempRoot() -> AppSupportPaths {
        AppSupportPaths(root: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString))
    }

    private func makeVM(
        _ driver: DBRecordingDriver,
        history: QueryHistoryStore,
        favorites: QueryFavoriteStore
    ) -> DatabaseV2ViewModel {
        DatabaseV2ViewModel(
            tools: FakeDatabaseTools(),
            historyStore: history,
            favoriteStore: favorites,
            makeDriver: { _, _ in driver },
            passwordFor: { _ in nil }
        )
    }

    func testRunRecordsHistoryWithConnectionAndDatabase() async {
        let history = QueryHistoryStore(paths: tempRoot())
        let vm = makeVM(DBRecordingDriver(), history: history, favorites: QueryFavoriteStore(paths: tempRoot()))
        await vm.connect(profile: .managedMySQL)
        vm.queryText = "SELECT 1"
        await vm.runQuery()

        XCTAssertEqual(vm.queryHistory.first?.sql, "SELECT 1")
        XCTAssertEqual(vm.queryHistory.first?.connectionLabel, ConnectionProfile.managedMySQL.name)
        XCTAssertEqual(vm.queryHistory.first?.database, vm.selectedDatabase)
    }

    func testClearHistoryEmptiesList() async {
        let vm = makeVM(DBRecordingDriver(), history: QueryHistoryStore(paths: tempRoot()), favorites: QueryFavoriteStore(paths: tempRoot()))
        await vm.connect(profile: .managedMySQL)
        vm.queryText = "SELECT 1"
        await vm.runQuery()
        XCTAssertFalse(vm.queryHistory.isEmpty)

        vm.clearHistory()
        XCTAssertTrue(vm.queryHistory.isEmpty)
    }

    func testFavoriteSaveAndDeleteRoundTrip() async {
        let favorites = QueryFavoriteStore(paths: tempRoot())
        let vm = makeVM(DBRecordingDriver(), history: QueryHistoryStore(paths: tempRoot()), favorites: favorites)
        await vm.connect(profile: .managedMySQL)
        vm.queryText = "SELECT * FROM users"
        vm.saveFavorite(name: "all users")

        XCTAssertEqual(vm.favorites.count, 1)
        XCTAssertEqual(vm.favorites.first?.name, "all users")
        XCTAssertEqual(vm.favorites.first?.sql, "SELECT * FROM users")

        let id = vm.favorites[0].id
        vm.deleteFavorite(id: id)
        XCTAssertTrue(vm.favorites.isEmpty)
    }

    func testFavoriteIgnoresEmptyNameOrSQL() async {
        let vm = makeVM(DBRecordingDriver(), history: QueryHistoryStore(paths: tempRoot()), favorites: QueryFavoriteStore(paths: tempRoot()))
        await vm.connect(profile: .managedMySQL)
        vm.queryText = ""
        vm.saveFavorite(name: "x")
        XCTAssertTrue(vm.favorites.isEmpty)

        vm.queryText = "SELECT 1"
        vm.saveFavorite(name: "   ")
        XCTAssertTrue(vm.favorites.isEmpty)
    }

    func testRecallHistoryOpensNonDestructiveNewTab() async {
        let vm = makeVM(DBRecordingDriver(), history: QueryHistoryStore(paths: tempRoot()), favorites: QueryFavoriteStore(paths: tempRoot()))
        await vm.connect(profile: .managedMySQL)
        vm.queryText = "SELECT current"
        let before = vm.queryTabs.count

        vm.recall(QueryHistoryEntry(sql: "SELECT recalled", connectionLabel: "c", database: nil))
        XCTAssertEqual(vm.queryTabs.count, before + 1)
        XCTAssertEqual(vm.queryText, "SELECT recalled")
        XCTAssertNil(vm.activeQuerySheet)
    }

    func testRecallFavoriteOpensNewTab() async {
        let vm = makeVM(DBRecordingDriver(), history: QueryHistoryStore(paths: tempRoot()), favorites: QueryFavoriteStore(paths: tempRoot()))
        await vm.connect(profile: .managedMySQL)
        vm.recall(QueryFavorite(name: "fav", sql: "SELECT fav"))
        XCTAssertEqual(vm.queryText, "SELECT fav")
        XCTAssertEqual(vm.activeQueryTab?.title, "fav")
    }

    func testPerTabDatabaseRoutesQuery() async {
        let driver = DBRecordingDriver()
        let vm = makeVM(driver, history: QueryHistoryStore(paths: tempRoot()), favorites: QueryFavoriteStore(paths: tempRoot()))
        await vm.connect(profile: .managedMySQL)
        vm.setQueryDatabase("other")
        vm.queryText = "SELECT 1"
        await vm.runQuery()

        XCTAssertEqual(vm.activeQueryDatabase, "other")
        XCTAssertEqual(driver.lastQueryDatabase, "other")
        XCTAssertEqual(vm.queryHistory.first?.database, "other")
    }

    func testFavoritesPersistTextOnlyAcrossReload() throws {
        let paths = tempRoot()
        let store = QueryFavoriteStore(paths: paths)
        try store.add(name: "keep", sql: "SELECT keep")

        let reloaded = QueryFavoriteStore(paths: paths)
        XCTAssertEqual(reloaded.entries().map(\.name), ["keep"])
        XCTAssertEqual(reloaded.entries().first?.sql, "SELECT keep")
    }
}
