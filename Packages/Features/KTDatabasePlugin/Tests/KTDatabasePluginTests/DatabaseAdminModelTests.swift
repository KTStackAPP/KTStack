import KTStackCore
import XCTest
@testable import KTDatabasePlugin

private final class AdminStubDriver: RelationalDriver, @unchecked Sendable {
    let kind: DatabaseKind = .mysql
    private let lock = NSLock()
    private var _close = 0
    let failPing: Bool
    var closeCount: Int { lock.withLock { _close } }

    init(failPing: Bool = false) {
        self.failPing = failPing
    }

    func ping() async throws {
        if failPing { throw DatabaseError.connection("server gone") }
    }
    func listDatabases() async throws -> [DatabaseInfo] { [] }
    func listTables(database _: String) async throws -> [TableInfo] { [] }
    func columns(database _: String, table _: String) async throws -> [ColumnInfo] { [] }
    func allColumns(database _: String) async throws -> [String: [String]] { [:] }
    func allColumnsDetailed(database _: String) async throws -> [String: [ColumnInfo]] { [:] }
    func indexes(database _: String, table _: String) async throws -> [IndexInfo] { [] }
    func foreignKeys(database _: String) async throws -> [ForeignKeyRelation] { [] }
    func query(_: String, database _: String?) async throws -> QueryResult {
        QueryResult(columns: [], rows: [])
    }
    func paginatedRows(database _: String, table _: String, limit _: Int, offset _: Int) async throws -> QueryResult {
        QueryResult(columns: [], rows: [])
    }
    func openSession() async throws {}
    func closeSession() async { lock.withLock { _close += 1 } }
    func runSelect(_: DMLStatement, database _: String?) async throws -> QueryResult {
        QueryResult(columns: [], rows: [])
    }
    func insert(database _: String, table _: String, values _: [ColumnValue]) async throws {}
    func update(database _: String, table _: String, values _: [ColumnValue], key _: [ColumnValue]) async throws {}
    func delete(database _: String, table _: String, key _: [ColumnValue]) async throws {}
}

@MainActor
final class DatabaseAdminModelTests: XCTestCase {
    private func makeModel(_ driver: AdminStubDriver?) -> DatabaseAdminModel {
        DatabaseAdminModel(
            tools: FakeDatabaseTools(),
            makeDriver: { _, _ in driver },
            passwordFor: { _ in nil }
        )
    }

    func testSelectConnectsAndClosePreviousDriver() async {
        let first = AdminStubDriver()
        let model = makeModel(first)
        await model.select(profile: .managedMySQL)
        XCTAssertEqual(model.connection, .connected)
        XCTAssertEqual(model.selectedProfile?.id, ConnectionProfile.managedMySQL.id)
        await model.select(profile: .managedMySQL)
        XCTAssertEqual(first.closeCount, 1)
    }

    func testSelectReportsPingFailure() async {
        let model = makeModel(AdminStubDriver(failPing: true))
        await model.select(profile: .managedMySQL)
        XCTAssertEqual(model.connection, .failed(.connection("server gone")))
    }

    func testSelectWithoutDriverFails() async {
        let model = makeModel(nil)
        await model.select(profile: .managedMySQL)
        guard case .failed = model.connection else {
            return XCTFail("expected failure, got \(model.connection)")
        }
    }

    func testCloseResetsState() async {
        let driver = AdminStubDriver()
        let model = makeModel(driver)
        await model.select(profile: .managedMySQL)
        await model.close()
        XCTAssertEqual(model.connection, .idle)
        XCTAssertNil(model.selectedProfile)
        XCTAssertEqual(model.backupStatus, .idle)
        XCTAssertEqual(driver.closeCount, 1)
    }

    func testCreateDatabaseRefusedOnReadOnlyConnection() async {
        let model = makeModel(AdminStubDriver())
        var profile = ConnectionProfile.managedMySQL
        profile.readOnly = true
        await model.select(profile: profile)
        let created = await model.createDatabase(named: "shop")
        XCTAssertFalse(created)
        guard case .failed = model.backupStatus else {
            return XCTFail("expected failure, got \(model.backupStatus)")
        }
    }

    func testCreateDatabaseWithoutProfileIsNoop() async {
        let model = makeModel(AdminStubDriver())
        let created = await model.createDatabase(named: "shop")
        XCTAssertFalse(created)
        XCTAssertEqual(model.backupStatus, .idle)
    }
}
