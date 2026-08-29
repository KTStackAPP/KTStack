import KTStackCore
import XCTest
@testable import KTDatabasePlugin

private final class LifecycleDriver: RelationalDriver, @unchecked Sendable {
    let kind: DatabaseKind = .mysql
    var capabilities: DriverCapabilities { DriverCapabilities() }
    private let lock = NSLock()
    private var _ping = 0
    private var _open = 0
    private var _close = 0
    var pingCount: Int { lock.withLock { _ping } }
    var openCount: Int { lock.withLock { _open } }
    var closeCount: Int { lock.withLock { _close } }

    func ping() async throws { lock.withLock { _ping += 1 } }
    func listDatabases() async throws -> [DatabaseInfo] { [DatabaseInfo(name: "db")] }
    func listTables(database _: String) async throws -> [TableInfo] { [TableInfo(name: "t")] }
    func columns(database _: String, table _: String) async throws -> [ColumnInfo] {
        [
            ColumnInfo(name: "id", dataType: "int", isNullable: false, isPrimaryKey: true),
            ColumnInfo(name: "name", dataType: "varchar", isNullable: true, isPrimaryKey: false),
        ]
    }
    func allColumns(database _: String) async throws -> [String: [String]] { ["t": ["id", "name"]] }
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
    func openSession() async throws { lock.withLock { _open += 1 } }
    func closeSession() async { lock.withLock { _close += 1 } }
    func runSelect(_: DMLStatement, database _: String?) async throws -> QueryResult {
        QueryResult(columns: [ColumnMeta(name: "id")], rows: [])
    }
    func insert(database _: String, table _: String, values _: [ColumnValue]) async throws {}
    func update(database _: String, table _: String, values _: [ColumnValue], key _: [ColumnValue]) async throws {}
    func delete(database _: String, table _: String, key _: [ColumnValue]) async throws {}
}

@MainActor
final class DatabaseV2ViewModelSuspendResumeTests: XCTestCase {
    private func makeVM(_ driver: LifecycleDriver) -> DatabaseV2ViewModel {
        DatabaseV2ViewModel(
            tools: FakeDatabaseTools(),
            historyStore: QueryHistoryStore(paths: AppSupportPaths(root: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString))),
            favoriteStore: QueryFavoriteStore(paths: AppSupportPaths(root: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString))),
            makeDriver: { _, _ in driver },
            passwordFor: { _ in nil }
        )
    }

    private func waitForRows(_ vm: DatabaseV2ViewModel) async {
        for _ in 0..<200 where vm.rows == nil || vm.isLoadingRows || vm.isLoadingStructure {
            try? await Task.sleep(nanoseconds: 5_000_000)
        }
    }

    func testSuspendKeepsRowsAndClosesDriver() async {
        let driver = LifecycleDriver()
        let vm = makeVM(driver)
        await vm.connect(profile: .managedMySQL)
        vm.select(table: TableInfo(name: "t"))
        await waitForRows(vm)
        XCTAssertNotNil(vm.rows)
        let loaded = vm.rows?.rowCount

        await vm.suspendConnection()
        XCTAssertTrue(vm.isSuspended)
        XCTAssertNil(vm.driver)
        XCTAssertEqual(vm.rows?.rowCount, loaded)
        XCTAssertGreaterThanOrEqual(driver.closeCount, 1)
    }

    func testSuspendKeepsPendingChangeCount() async {
        let driver = LifecycleDriver()
        let vm = makeVM(driver)
        await vm.connect(profile: .managedMySQL)
        vm.select(table: TableInfo(name: "t"))
        await waitForRows(vm)
        vm.stageCellEdit(row: 0, column: 1, newValue: "edited")
        XCTAssertEqual(vm.pendingChangeCount, 1)

        await vm.suspendConnection()
        XCTAssertEqual(vm.pendingChangeCount, 1)
    }

    func testLoadRowsAfterSuspendAutoResumes() async {
        let driver = LifecycleDriver()
        let vm = makeVM(driver)
        await vm.connect(profile: .managedMySQL)
        vm.select(table: TableInfo(name: "t"))
        await waitForRows(vm)
        let pingsAfterConnect = driver.pingCount

        await vm.suspendConnection()
        await vm.loadRows(table: TableInfo(name: "t"))
        XCTAssertFalse(vm.isSuspended)
        XCTAssertNotNil(vm.driver)
        XCTAssertGreaterThan(driver.pingCount, pingsAfterConnect)
        XCTAssertNotNil(vm.rows)
    }

    func testResumeIsNoopWhenNotSuspended() async {
        let driver = LifecycleDriver()
        let vm = makeVM(driver)
        await vm.connect(profile: .managedMySQL)
        let pings = driver.pingCount
        await vm.resumeConnection()
        XCTAssertEqual(driver.pingCount, pings)
    }
}
