import KTStackCore
import XCTest
@testable import KTDatabasePlugin

/// COUNT(*) lười: estimate được điền sau khi load bảng, và tính lại khi bộ lọc đổi.
@MainActor
final class DatabaseV2ViewModelRowCountTests: XCTestCase {
    private final class CountDriver: RelationalDriver, @unchecked Sendable {
        let kind: DatabaseKind = .mysql
        var count = 4200
        private(set) var countCalls = 0

        func ping() async throws {}
        func listDatabases() async throws -> [DatabaseInfo] { [DatabaseInfo(name: "app")] }
        func listTables(database _: String) async throws -> [TableInfo] { [TableInfo(name: "users")] }
        func columns(database _: String, table _: String) async throws -> [ColumnInfo] {
            [ColumnInfo(name: "id", dataType: "int", isNullable: false, isPrimaryKey: true)]
        }

        func indexes(database _: String, table _: String) async throws -> [IndexInfo] { [] }
        func foreignKeys(database _: String) async throws -> [ForeignKeyRelation] { [] }
        func allColumns(database _: String) async throws -> [String: [String]] { [:] }
        func allColumnsDetailed(database _: String) async throws -> [String: [ColumnInfo]] { [:] }
        func openSession() async throws {}
        func closeSession() async {}
        func runSelect(_ statement: DMLStatement, database _: String?) async throws -> QueryResult {
            if statement.sql.contains("COUNT(*)") {
                countCalls += 1
                return QueryResult(columns: [ColumnMeta(name: "c")], rows: [[.int(Int64(count))]])
            }
            return QueryResult(columns: [ColumnMeta(name: "id")], rows: [[.int(1)]])
        }

        func insert(database _: String, table _: String, values _: [ColumnValue]) async throws {}
        func update(database _: String, table _: String, values _: [ColumnValue], key _: [ColumnValue]) async throws {}
        func delete(database _: String, table _: String, key _: [ColumnValue]) async throws {}
        func paginatedRows(database _: String, table _: String, limit _: Int, offset _: Int) async throws -> QueryResult {
            QueryResult(columns: [ColumnMeta(name: "id")], rows: [[.int(1)]])
        }

        func query(_: String, database _: String?) async throws -> QueryResult {
            QueryResult(columns: [ColumnMeta(name: "id")], rows: [[.int(1)]])
        }

        func serverVersion() async throws -> String { "8.0" }
    }

    private func tempRoot() -> AppSupportPaths {
        AppSupportPaths(root: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString))
    }

    private func makeVM(_ driver: CountDriver) -> DatabaseV2ViewModel {
        DatabaseV2ViewModel(
            tools: FakeDatabaseTools(),
            historyStore: QueryHistoryStore(paths: tempRoot()),
            favoriteStore: QueryFavoriteStore(paths: tempRoot()),
            makeDriver: { _, _ in driver },
            passwordFor: { _ in nil }
        )
    }

    private func waitUntil(_ condition: @escaping () -> Bool, timeout: TimeInterval = 2) async {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if condition() { return }
            try? await Task.sleep(nanoseconds: 20_000_000)
        }
    }

    func testEstimatePopulatedAfterLoad() async {
        let driver = CountDriver()
        let vm = makeVM(driver)
        await vm.connect(profile: .managedMySQL)
        vm.select(table: TableInfo(name: "users"))
        await waitUntil { vm.rowCountEstimate != nil }

        XCTAssertEqual(vm.rowCountEstimate, 4200)
        XCTAssertFalse(vm.isCountingRows)
    }

    func testFilterChangeRecomputesEstimate() async {
        let driver = CountDriver()
        let vm = makeVM(driver)
        await vm.connect(profile: .managedMySQL)
        vm.select(table: TableInfo(name: "users"))
        await waitUntil { vm.rowCountEstimate != nil }

        driver.count = 12
        vm.applyFilters([FilterCondition(column: "id", op: .greaterThan, value: .int(1))])
        await waitUntil { vm.rowCountEstimate == 12 }

        XCTAssertEqual(vm.rowCountEstimate, 12)
        XCTAssertGreaterThanOrEqual(driver.countCalls, 2)
    }
}
