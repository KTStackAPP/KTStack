import KTStackCore
import XCTest
@testable import KTDatabasePlugin

/// Engine-free tests for the run-path guards: read-only rejection, destructive confirm, and EXPLAIN.
@MainActor
final class V2QueryGuardTests: XCTestCase {
    private final class QueryStub: RelationalDriver, @unchecked Sendable {
        let kind: DatabaseKind = .mysql
        private(set) var queryCalls: [String] = []

        func ping() async throws {}
        func listDatabases() async throws -> [DatabaseInfo] { [DatabaseInfo(name: "app")] }
        func listTables(database _: String) async throws -> [TableInfo] { [] }
        func columns(database _: String, table _: String) async throws -> [ColumnInfo] { [] }
        func indexes(database _: String, table _: String) async throws -> [IndexInfo] { [] }
        func foreignKeys(database _: String) async throws -> [ForeignKeyRelation] { [] }
        func allColumns(database _: String) async throws -> [String: [String]] { [:] }
        func allColumnsDetailed(database _: String) async throws -> [String: [ColumnInfo]] { [:] }
        func openSession() async throws {}
        func closeSession() async {}
        func runSelect(_ statement: DMLStatement, database _: String?) async throws -> QueryResult {
            queryCalls.append(statement.sql)
            return QueryResult(columns: [ColumnMeta(name: "id")], rows: [[.int(1)]])
        }

        func insert(database _: String, table _: String, values _: [ColumnValue]) async throws {}
        func update(database _: String, table _: String, values _: [ColumnValue], key _: [ColumnValue]) async throws {}
        func delete(database _: String, table _: String, key _: [ColumnValue]) async throws {}
        func paginatedRows(database _: String, table _: String, limit _: Int, offset _: Int) async throws -> QueryResult {
            QueryResult(columns: [ColumnMeta(name: "id")], rows: [[.int(1)]])
        }

        func query(_ sql: String, database _: String?) async throws -> QueryResult {
            queryCalls.append(sql)
            if sql.hasPrefix("EXPLAIN") {
                return QueryResult(columns: [ColumnMeta(name: "EXPLAIN")], rows: [[.text("-> Limit\n    -> Table scan on t")]])
            }
            return QueryResult(columns: [ColumnMeta(name: "id")], rows: [[.int(1)]])
        }
    }

    private func tempRoot() -> AppSupportPaths {
        AppSupportPaths(root: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString))
    }

    private func makeVM(_ driver: QueryStub) -> DatabaseV2ViewModel {
        DatabaseV2ViewModel(
            tools: FakeDatabaseTools(),
            historyStore: QueryHistoryStore(paths: tempRoot()),
            favoriteStore: QueryFavoriteStore(paths: tempRoot()),
            makeDriver: { _, _ in driver },
            passwordFor: { _ in nil }
        )
    }

    private func readOnlyProfile() -> ConnectionProfile {
        ConnectionProfile(name: "ro", kind: .mysql, host: "127.0.0.1", port: 3306, user: "u", database: "app", readOnly: true)
    }

    func testReadOnlyBlocksWriteWithoutRunning() async {
        let driver = QueryStub()
        let vm = makeVM(driver)
        await vm.connect(profile: readOnlyProfile())
        vm.queryText = "DELETE FROM t WHERE id = 1"
        await vm.runQuery()

        XCTAssertTrue(driver.queryCalls.isEmpty)
        XCTAssertEqual(vm.activeQueryResult?.label, "Blocked")
        XCTAssertTrue(vm.queryError?.contains("read-only") ?? false)
    }

    func testReadOnlyAllowsRead() async {
        let driver = QueryStub()
        let vm = makeVM(driver)
        await vm.connect(profile: readOnlyProfile())
        vm.queryText = "SELECT 1"
        await vm.runQuery()

        XCTAssertEqual(driver.queryCalls.count, 1)
    }

    func testDestructivePromptsBeforeRunning() async {
        let driver = QueryStub()
        let vm = makeVM(driver)
        await vm.connect(profile: .managedMySQL)
        vm.queryText = "DROP TABLE t"
        await vm.runQuery()

        XCTAssertNotNil(vm.destructivePrompt)
        XCTAssertTrue(driver.queryCalls.isEmpty)
    }

    func testConfirmDestructiveRuns() async {
        let driver = QueryStub()
        let vm = makeVM(driver)
        await vm.connect(profile: .managedMySQL)
        vm.queryText = "DROP TABLE t"
        await vm.runQuery()
        await vm.confirmDestructiveRun()

        XCTAssertNil(vm.destructivePrompt)
        XCTAssertEqual(driver.queryCalls, ["DROP TABLE t"])
    }

    func testCancelDestructiveClearsWithoutRunning() async {
        let driver = QueryStub()
        let vm = makeVM(driver)
        await vm.connect(profile: .managedMySQL)
        vm.queryText = "TRUNCATE t"
        await vm.runQuery()
        vm.cancelDestructiveRun()

        XCTAssertNil(vm.destructivePrompt)
        XCTAssertTrue(driver.queryCalls.isEmpty)
    }

    func testExplainBuildsTreeSheet() async {
        let driver = QueryStub()
        let vm = makeVM(driver)
        await vm.connect(profile: .managedMySQL)
        vm.queryText = "SELECT * FROM t"
        await vm.explainActiveQuery()

        XCTAssertEqual(driver.queryCalls.first, "EXPLAIN FORMAT=TREE SELECT * FROM t")
        XCTAssertNotNil(vm.explainSheet?.tree)
        XCTAssertEqual(vm.explainSheet?.tree?.first?.text, "Limit")
    }
}
