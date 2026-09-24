import KTStackCore
import XCTest
@testable import KTDatabasePlugin

@MainActor
final class DatabaseV2ViewModelStagingGuardTests: XCTestCase {
    private final class StagingDriver: RelationalDriver, @unchecked Sendable {
        let kind: DatabaseKind = .mysql
        var capabilities: DriverCapabilities { DriverCapabilities(canEditRows: true) }
        var commitDelay: Duration = .zero
        private let lock = NSLock()
        private var _committedBatches: [[WriteStep]] = []
        private var _queries: [String] = []
        var committedBatches: [[WriteStep]] { lock.withLock { _committedBatches } }
        var queries: [String] { lock.withLock { _queries } }

        private let columnInfo = [
            ColumnInfo(name: "id", dataType: "int", isNullable: false, isPrimaryKey: true),
            ColumnInfo(name: "name", dataType: "varchar(50)", isNullable: true, isPrimaryKey: false),
        ]

        private func page() -> QueryResult {
            QueryResult(
                columns: [ColumnMeta(name: "id"), ColumnMeta(name: "name")],
                rows: (1...5).map { [Cell.int(Int64($0)), Cell.text("n\($0)")] }
            )
        }

        func ping() async throws {}
        func listDatabases() async throws -> [DatabaseInfo] { [DatabaseInfo(name: "shop")] }
        func listTables(database _: String) async throws -> [TableInfo] { [TableInfo(name: "users"), TableInfo(name: "posts")] }
        func columns(database _: String, table _: String) async throws -> [ColumnInfo] { columnInfo }
        func allColumns(database _: String) async throws -> [String: [String]] { [:] }
        func allColumnsDetailed(database _: String) async throws -> [String: [ColumnInfo]] { [:] }
        func indexes(database _: String, table _: String) async throws -> [IndexInfo] { [] }
        func foreignKeys(database _: String) async throws -> [ForeignKeyRelation] {
            [ForeignKeyRelation(fromTable: "users", fromColumn: "name", toTable: "posts", toColumn: "id", constraintName: "fk")]
        }
        func query(_ sql: String, database _: String?) async throws -> QueryResult {
            lock.withLock { _queries.append(sql) }
            return QueryResult(columns: [], rows: [])
        }
        func paginatedRows(database _: String, table _: String, limit _: Int, offset _: Int) async throws -> QueryResult { page() }
        func openSession() async throws {}
        func closeSession() async {}
        func runSelect(_: DMLStatement, database _: String?) async throws -> QueryResult { page() }
        func insert(database _: String, table _: String, values _: [ColumnValue]) async throws {}
        func update(database _: String, table _: String, values _: [ColumnValue], key _: [ColumnValue]) async throws {}
        func delete(database _: String, table _: String, key _: [ColumnValue]) async throws {}
        func executeTransaction(_ steps: [WriteStep], database _: String) async throws {
            if commitDelay > .zero { try await Task.sleep(for: commitDelay) }
            lock.withLock { _committedBatches.append(steps) }
        }
    }

    private func makeVM(_ driver: StagingDriver) async throws -> DatabaseV2ViewModel {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let vm = DatabaseV2ViewModel(
            tools: FakeDatabaseTools(),
            historyStore: QueryHistoryStore(paths: AppSupportPaths(root: root)),
            favoriteStore: QueryFavoriteStore(paths: AppSupportPaths(root: root)),
            makeDriver: { _, _ in driver },
            passwordFor: { _ in nil }
        )
        await vm.connect(profile: .managedMySQL)
        vm.select(table: TableInfo(name: "users"))
        for _ in 0..<100 where vm.staged == nil || vm.rows == nil {
            try await Task.sleep(for: .milliseconds(10))
        }
        XCTAssertNotNil(vm.staged)
        return vm
    }

    private func settle() async throws {
        try await Task.sleep(for: .milliseconds(150))
    }

    func testSecondCommitWhileCommittingIsIgnored() async throws {
        let driver = StagingDriver()
        driver.commitDelay = .milliseconds(200)
        let vm = try await makeVM(driver)
        vm.stageCellEdit(row: 0, column: 1, newValue: "changed")
        async let first: Void = vm.commitStaged()
        try await Task.sleep(for: .milliseconds(20))
        await vm.commitStaged()
        await first
        XCTAssertEqual(driver.committedBatches.count, 1)
    }

    func testEditStagedDuringCommitIsNotLost() async throws {
        let driver = StagingDriver()
        driver.commitDelay = .milliseconds(200)
        let vm = try await makeVM(driver)
        vm.stageCellEdit(row: 0, column: 1, newValue: "first")
        async let commit: Void = vm.commitStaged()
        try await Task.sleep(for: .milliseconds(20))
        vm.stageCellEdit(row: 1, column: 1, newValue: "second")
        await commit
        XCTAssertEqual(vm.pendingChangeCount, 1)
    }

    func testSortKeepsPendingEdits() async throws {
        let vm = try await makeVM(StagingDriver())
        vm.stageCellEdit(row: 0, column: 1, newValue: "changed")
        vm.setBrowseSort(SortSpec(column: "name", ascending: false))
        try await settle()
        XCTAssertEqual(vm.pendingChangeCount, 1)
    }

    func testFilterKeepsPendingEdits() async throws {
        let vm = try await makeVM(StagingDriver())
        vm.stageCellEdit(row: 0, column: 1, newValue: "changed")
        vm.applyFilters([FilterCondition(column: "name", op: .isNotNull, value: .null)])
        try await settle()
        XCTAssertEqual(vm.pendingChangeCount, 1)
    }

    func testForeignKeyJumpIsRefusedWithPendingEdits() async throws {
        let vm = try await makeVM(StagingDriver())
        vm.stageCellEdit(row: 0, column: 1, newValue: "changed")
        vm.navigateForeignKey(row: 1, column: 1)
        XCTAssertEqual(vm.selectedTable?.name, "users")
        XCTAssertEqual(vm.pendingChangeCount, 1)
        XCTAssertNotNil(vm.editError)
    }

    func testDDLIsRefusedWithPendingEdits() async throws {
        let driver = StagingDriver()
        let vm = try await makeVM(driver)
        vm.stageCellEdit(row: 0, column: 1, newValue: "changed")
        await vm.runDDL("ALTER TABLE users ADD COLUMN x int")
        XCTAssertTrue(driver.queries.isEmpty)
        XCTAssertNotNil(vm.ddlError)
        XCTAssertEqual(vm.pendingChangeCount, 1)
    }
}
