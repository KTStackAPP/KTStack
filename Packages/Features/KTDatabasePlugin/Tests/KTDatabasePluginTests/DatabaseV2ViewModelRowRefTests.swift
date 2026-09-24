import KTStackCore
import XCTest
@testable import KTDatabasePlugin

@MainActor
final class DatabaseV2ViewModelRowRefTests: XCTestCase {
    private final class RowsDriver: RelationalDriver, @unchecked Sendable {
        let kind: DatabaseKind = .mysql
        var capabilities: DriverCapabilities { DriverCapabilities(canEditRows: true) }

        private func page() -> QueryResult {
            QueryResult(
                columns: [ColumnMeta(name: "id"), ColumnMeta(name: "name")],
                rows: (1...5).map { [Cell.int(Int64($0)), Cell.text("n\($0)")] }
            )
        }

        func ping() async throws {}
        func listDatabases() async throws -> [DatabaseInfo] { [DatabaseInfo(name: "shop")] }
        func listTables(database _: String) async throws -> [TableInfo] { [TableInfo(name: "users"), TableInfo(name: "posts")] }
        func columns(database _: String, table _: String) async throws -> [ColumnInfo] {
            [
                ColumnInfo(name: "id", dataType: "int", isNullable: false, isPrimaryKey: true),
                ColumnInfo(name: "name", dataType: "varchar(50)", isNullable: true, isPrimaryKey: false),
            ]
        }
        func allColumns(database _: String) async throws -> [String: [String]] { [:] }
        func allColumnsDetailed(database _: String) async throws -> [String: [ColumnInfo]] { [:] }
        func indexes(database _: String, table _: String) async throws -> [IndexInfo] { [] }
        func foreignKeys(database _: String) async throws -> [ForeignKeyRelation] { [] }
        func query(_: String, database _: String?) async throws -> QueryResult { QueryResult(columns: [], rows: []) }
        func paginatedRows(database _: String, table _: String, limit _: Int, offset _: Int) async throws -> QueryResult { page() }
        func openSession() async throws {}
        func closeSession() async {}
        func runSelect(_: DMLStatement, database _: String?) async throws -> QueryResult { page() }
        func insert(database _: String, table _: String, values _: [ColumnValue]) async throws {}
        func update(database _: String, table _: String, values _: [ColumnValue], key _: [ColumnValue]) async throws {}
        func delete(database _: String, table _: String, key _: [ColumnValue]) async throws {}
        func executeTransaction(_: [WriteStep], database _: String) async throws {}
    }

    private func makeVM() async throws -> DatabaseV2ViewModel {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let driver = RowsDriver()
        let vm = DatabaseV2ViewModel(
            tools: FakeDatabaseTools(),
            historyStore: QueryHistoryStore(paths: AppSupportPaths(root: root)),
            favoriteStore: QueryFavoriteStore(paths: AppSupportPaths(root: root)),
            makeDriver: { _, _ in driver },
            passwordFor: { _ in nil }
        )
        await vm.connect(profile: .managedMySQL)
        vm.select(table: TableInfo(name: "users"))
        try await waitForStagedTable("users", vm)
        return vm
    }

    private func waitForStagedTable(_ name: String, _ vm: DatabaseV2ViewModel) async throws {
        for _ in 0..<100 where vm.staged == nil || vm.rows == nil || vm.selectedTable?.name != name {
            try await Task.sleep(for: .milliseconds(10))
        }
        try await Task.sleep(for: .milliseconds(50))
        XCTAssertNotNil(vm.staged)
    }

    func testRefCapturesTheRowValues() async throws {
        let vm = try await makeVM()
        XCTAssertEqual(vm.rowRef(at: 2), .row(table: "users", values: ["id": .int(3), "name": .text("n3")]))
        XCTAssertNil(vm.rowRef(at: 9))
    }

    func testEditThroughARefStagesTheCapturedRow() async throws {
        let vm = try await makeVM()
        let ref = try XCTUnwrap(vm.rowRef(at: 2))
        vm.stageOrDraftEdit(ref: ref, column: "name", value: "changed")
        XCTAssertEqual(vm.pendingChangeCount, 1)
        XCTAssertEqual(vm.displayRows?.rows[2][1], .text("changed"))
        XCTAssertEqual(vm.displayRows?.rows[1][1], .text("n2"))
    }

    func testRefFromAnotherTableIsIgnored() async throws {
        let vm = try await makeVM()
        let ref = try XCTUnwrap(vm.rowRef(at: 0))
        vm.select(table: TableInfo(name: "posts"))
        try await waitForStagedTable("posts", vm)
        vm.stageOrDraftEdit(ref: ref, column: "name", value: "stray")
        XCTAssertEqual(vm.pendingChangeCount, 0)
    }

    func testDraftRefEditsTheInsertDraft() async throws {
        let vm = try await makeVM()
        vm.beginInsertDraft()
        XCTAssertEqual(vm.rowRef(at: 5), .draft)
        vm.stageOrDraftEdit(ref: .draft, column: "name", value: "new")
        XCTAssertEqual(vm.insertDraft?["name"], .value("new"))
    }
}
