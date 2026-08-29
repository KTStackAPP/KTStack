import KTStackCore
import XCTest
@testable import KTDatabasePlugin

/// Driver giả trả `limit` dòng (tới `total`) và ghi lại từng (offset, limit) để kiểm tra cửa sổ trượt.
private final class WindowDriver: RelationalDriver, @unchecked Sendable {
    let kind: DatabaseKind = .mysql
    var capabilities: DriverCapabilities { DriverCapabilities() }
    let total: Int
    private let lock = NSLock()
    private var _calls: [(limit: Int, offset: Int)] = []
    var calls: [(limit: Int, offset: Int)] { lock.withLock { _calls } }

    init(total: Int) { self.total = total }

    func ping() async throws {}
    func listDatabases() async throws -> [DatabaseInfo] { [DatabaseInfo(name: "db")] }
    func listTables(database _: String) async throws -> [TableInfo] { [TableInfo(name: "t")] }
    func columns(database _: String, table _: String) async throws -> [ColumnInfo] {
        [ColumnInfo(name: "id", dataType: "int", isNullable: false, isPrimaryKey: true)]
    }
    func allColumns(database _: String) async throws -> [String: [String]] { ["t": ["id"]] }
    func allColumnsDetailed(database _: String) async throws -> [String: [ColumnInfo]] { [:] }
    func indexes(database _: String, table _: String) async throws -> [IndexInfo] { [] }
    func foreignKeys(database _: String) async throws -> [ForeignKeyRelation] { [] }
    func query(_: String, database _: String?) async throws -> QueryResult {
        QueryResult(columns: [ColumnMeta(name: "id")], rows: [])
    }
    func paginatedRows(database _: String, table _: String, limit: Int, offset: Int) async throws -> QueryResult {
        lock.withLock { _calls.append((limit, offset)) }
        let count = max(0, min(limit, total - offset))
        let rows = (0..<count).map { [Cell.int(Int64(offset + $0))] }
        return QueryResult(columns: [ColumnMeta(name: "id")], rows: rows)
    }
    func openSession() async throws {}
    func closeSession() async {}
    func runSelect(_: DMLStatement, database _: String?) async throws -> QueryResult {
        QueryResult(columns: [ColumnMeta(name: "id")], rows: [])
    }
    func insert(database _: String, table _: String, values _: [ColumnValue]) async throws {}
    func update(database _: String, table _: String, values _: [ColumnValue], key _: [ColumnValue]) async throws {}
    func delete(database _: String, table _: String, key _: [ColumnValue]) async throws {}
}

@MainActor
final class DatabaseV2ViewModelSlidingWindowTests: XCTestCase {
    private func makeConnectedVM(total: Int) async -> (DatabaseV2ViewModel, WindowDriver) {
        let driver = WindowDriver(total: total)
        let vm = DatabaseV2ViewModel(
            tools: FakeDatabaseTools(),
            historyStore: QueryHistoryStore(paths: AppSupportPaths(root: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString))),
            favoriteStore: QueryFavoriteStore(paths: AppSupportPaths(root: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString))),
            makeDriver: { _, _ in driver },
            passwordFor: { _ in nil }
        )
        await vm.connect(profile: .managedMySQL)
        vm.select(table: TableInfo(name: "t"))
        await waitForRows(vm)
        return (vm, driver)
    }

    private func waitForRows(_ vm: DatabaseV2ViewModel) async {
        for _ in 0..<200 where vm.rows == nil || vm.isLoadingRows {
            try? await Task.sleep(nanoseconds: 5_000_000)
        }
    }

    func testFetchMoreCapsWindowAndAdvancesStart() async {
        let (vm, _) = await makeConnectedVM(total: 100_000)
        XCTAssertEqual(vm.rows?.rowCount, 200)
        XCTAssertEqual(vm.windowStart, 0)
        for _ in 0..<20 { await vm.fetchMore() }
        // Trần 5 trang × 200 = 1000; invariant pageOffset == windowStart + rows.count.
        XCTAssertEqual(vm.rows?.rowCount, 1000)
        XCTAssertEqual(vm.pageOffset, 4200)
        XCTAssertEqual(vm.windowStart, 3200)
        XCTAssertEqual(vm.pageOffset, vm.windowStart + (vm.rows?.rowCount ?? 0))
        // Hàng đầu cửa sổ là dòng tuyệt đối windowStart.
        if case let .int(first)? = vm.rows?.rows.first?.first { XCTAssertEqual(first, 3200) }
    }

    func testFetchPreviousLoadsPriorPageAndKeepsInvariant() async {
        let (vm, driver) = await makeConnectedVM(total: 100_000)
        for _ in 0..<20 { await vm.fetchMore() }
        let startBefore = vm.windowStart
        await vm.fetchPrevious()
        XCTAssertEqual(vm.windowStart, startBefore - 200)
        XCTAssertEqual(vm.rows?.rowCount, 1000)
        XCTAssertEqual(vm.pageOffset, vm.windowStart + (vm.rows?.rowCount ?? 0))
        XCTAssertTrue(vm.hasMore)
        XCTAssertTrue(driver.calls.contains { $0.offset == startBefore - 200 })
    }

    func testFetchPreviousNoopAtTop() async {
        let (vm, _) = await makeConnectedVM(total: 500)
        XCTAssertEqual(vm.windowStart, 0)
        await vm.fetchPrevious()
        XCTAssertEqual(vm.windowStart, 0)
    }
}
