import KTStackCore
import XCTest
@testable import KTDatabasePlugin

/// Engine-free coverage of the V2 multi-statement query run: ordered results, mid-batch stop on error,
/// row cap + Fetch All, and pin retention across runs.
@MainActor
final class V2QueryRunTests: XCTestCase {
    private final class StubDriver: RelationalDriver, @unchecked Sendable {
        let kind: DatabaseKind = .mysql
        private(set) var queryCalls: [String] = []
        private(set) var selectCalls: [(sql: String, binds: [Cell])] = []
        var rowsPerQuery = 1
        var failOnContaining: String?

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
            selectCalls.append((statement.sql, statement.binds))
            if let needle = failOnContaining, statement.sql.contains(needle) {
                throw DatabaseError.syntax("boom")
            }
            let rows = (0..<rowsPerQuery).map { [Cell.int(Int64($0))] }
            return QueryResult(columns: [ColumnMeta(name: "id")], rows: rows)
        }

        func insert(database _: String, table _: String, values _: [ColumnValue]) async throws {}
        func update(database _: String, table _: String, values _: [ColumnValue], key _: [ColumnValue]) async throws {}
        func delete(database _: String, table _: String, key _: [ColumnValue]) async throws {}

        func paginatedRows(database _: String, table _: String, limit _: Int, offset _: Int) async throws -> QueryResult {
            QueryResult(columns: [ColumnMeta(name: "id")], rows: [[.int(1)]])
        }

        func query(_ sql: String, database _: String?) async throws -> QueryResult {
            queryCalls.append(sql)
            if let needle = failOnContaining, sql.contains(needle) {
                throw DatabaseError.syntax("boom")
            }
            let rows = (0..<rowsPerQuery).map { [Cell.int(Int64($0))] }
            return QueryResult(columns: [ColumnMeta(name: "id")], rows: rows)
        }
    }

    private func makeVM(_ driver: StubDriver) -> DatabaseV2ViewModel {
        DatabaseV2ViewModel(
            tools: FakeDatabaseTools(),
            historyStore: QueryHistoryStore(paths: AppSupportPaths(root: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString))),
            favoriteStore: QueryFavoriteStore(paths: AppSupportPaths(root: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString))),
            makeDriver: { _, _ in driver },
            passwordFor: { _ in nil }
        )
    }

    func testThreeStatementsProduceThreeOrderedResults() async {
        let driver = StubDriver()
        let vm = makeVM(driver)
        await vm.connect(profile: .managedMySQL)
        vm.queryText = "SELECT 1; SELECT 2; SELECT 3"
        await vm.runQuery()

        XCTAssertEqual(vm.queryResults.count, 3)
        XCTAssertEqual(vm.queryResults.map(\.label), ["Result 1", "Result 2", "Result 3"])
        XCTAssertEqual(vm.activeQueryResult?.label, "Result 1")
        XCTAssertNil(vm.queryError)
    }

    func testFailedStatementStopsBatchWithPreciseError() async {
        let driver = StubDriver()
        driver.failOnContaining = "SELECT 2"
        let vm = makeVM(driver)
        await vm.connect(profile: .managedMySQL)
        vm.queryText = "SELECT 1; SELECT 2; SELECT 3"
        await vm.runQuery()

        XCTAssertEqual(vm.queryResults.count, 2)
        XCTAssertNil(vm.queryResults[0].error)
        XCTAssertNotNil(vm.queryResults[1].error)
        // Câu thứ ba không được chạy.
        XCTAssertEqual(driver.queryCalls.count, 2)
    }

    func testBareSelectAppliesRowCap() async {
        let driver = StubDriver()
        driver.rowsPerQuery = SQLAutoLimit.defaultMax
        let vm = makeVM(driver)
        await vm.connect(profile: .managedMySQL)
        vm.queryText = "SELECT * FROM users"
        await vm.runQuery()

        let item = vm.activeQueryResult
        XCTAssertEqual(item?.capApplied, true)
        XCTAssertEqual(item?.isTruncatedByCap, true)
        XCTAssertTrue(driver.queryCalls.first?.contains("LIMIT \(SQLAutoLimit.defaultMax)") ?? false)
    }

    func testFetchAllReRunsWithoutCap() async {
        let driver = StubDriver()
        driver.rowsPerQuery = SQLAutoLimit.defaultMax
        let vm = makeVM(driver)
        await vm.connect(profile: .managedMySQL)
        vm.queryText = "SELECT * FROM users"
        await vm.runQuery()
        let id = try! XCTUnwrap(vm.activeQueryResult?.id)

        await vm.fetchAll(resultID: id)

        XCTAssertEqual(vm.activeQueryResult?.capApplied, false)
        XCTAssertEqual(driver.queryCalls.count, 2)
        XCTAssertEqual(driver.queryCalls.last, "SELECT * FROM users")
    }

    func testParameterizedQueryPromptsBeforeRunning() async {
        let driver = StubDriver()
        let vm = makeVM(driver)
        await vm.connect(profile: .managedMySQL)
        vm.queryText = "SELECT * FROM users WHERE id = :id"
        await vm.runQuery()

        XCTAssertEqual(vm.parameterPrompt?.names, ["id"])
        XCTAssertTrue(driver.queryCalls.isEmpty)
        XCTAssertTrue(driver.selectCalls.isEmpty)
    }

    func testSubmitParametersRunsBoundStatement() async {
        let driver = StubDriver()
        let vm = makeVM(driver)
        await vm.connect(profile: .managedMySQL)
        vm.queryText = "SELECT * FROM users WHERE id = :id"
        await vm.runQuery()
        await vm.submitParameters(["id": "7"])

        XCTAssertNil(vm.parameterPrompt)
        XCTAssertEqual(driver.selectCalls.count, 1)
        XCTAssertTrue(driver.selectCalls[0].sql.contains("id = ?"))
        XCTAssertEqual(driver.selectCalls[0].binds, [.int(7)])
        XCTAssertTrue(driver.queryCalls.isEmpty)
        XCTAssertNotNil(vm.queryResult)
    }

    func testFetchAllReRunsParameterizedWithSameBinds() async {
        let driver = StubDriver()
        driver.rowsPerQuery = SQLAutoLimit.defaultMax
        let vm = makeVM(driver)
        await vm.connect(profile: .managedMySQL)
        vm.queryText = "SELECT * FROM users WHERE id = :id"
        await vm.runQuery()
        await vm.submitParameters(["id": "7"])
        let id = try! XCTUnwrap(vm.activeQueryResult?.id)

        await vm.fetchAll(resultID: id)

        XCTAssertEqual(driver.selectCalls.count, 2)
        XCTAssertEqual(driver.selectCalls.last?.binds, [.int(7)])
        // Lần Fetch All chạy SQL chưa cap (không có LIMIT thêm).
        XCTAssertFalse(driver.selectCalls.last?.sql.contains("LIMIT") ?? true)
        XCTAssertEqual(vm.activeQueryResult?.capApplied, false)
    }

    func testPinnedResultSurvivesNextRun() async {
        let driver = StubDriver()
        let vm = makeVM(driver)
        await vm.connect(profile: .managedMySQL)
        vm.queryText = "SELECT 1"
        await vm.runQuery()
        let id = try! XCTUnwrap(vm.activeQueryResult?.id)
        vm.togglePinResult(id: id)

        vm.queryText = "SELECT 2"
        await vm.runQuery()

        XCTAssertEqual(vm.queryResults.count, 2)
        XCTAssertTrue(vm.queryResults.contains { $0.isPinned })
        XCTAssertEqual(vm.queryResults.last?.label, "Result 2")
    }
}
