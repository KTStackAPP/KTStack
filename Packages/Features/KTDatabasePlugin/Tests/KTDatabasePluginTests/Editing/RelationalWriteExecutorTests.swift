import XCTest
@testable import KTDatabasePlugin

final class RelationalWriteExecutorTests: XCTestCase {
    private final class RecordingDriver: RelationalDriver, @unchecked Sendable {
        let kind: DatabaseKind = .mysql
        var capabilitiesOverride = DriverCapabilities()
        var capabilities: DriverCapabilities { capabilitiesOverride }

        private(set) var committedBatches: [[WriteStep]] = []
        private(set) var committedDatabase: String?

        func executeTransaction(_ steps: [WriteStep], database: String) async throws {
            committedBatches.append(steps)
            committedDatabase = database
        }

        // Unused by the executor path.
        func ping() async throws {}
        func listDatabases() async throws -> [DatabaseInfo] { [] }
        func listTables(database _: String) async throws -> [TableInfo] { [] }
        func columns(database _: String, table _: String) async throws -> [ColumnInfo] { [] }
        func allColumns(database _: String) async throws -> [String: [String]] { [:] }
        func allColumnsDetailed(database _: String) async throws -> [String: [ColumnInfo]] { [:] }
        func indexes(database _: String, table _: String) async throws -> [IndexInfo] { [] }
        func foreignKeys(database _: String) async throws -> [ForeignKeyRelation] { [] }
        func query(_: String, database _: String?) async throws -> QueryResult { QueryResult(columns: [], rows: []) }
        func paginatedRows(database _: String, table _: String, limit _: Int, offset _: Int) async throws -> QueryResult {
            QueryResult(columns: [], rows: [])
        }
        func openSession() async throws {}
        func closeSession() async {}
        func runSelect(_: DMLStatement, database _: String?) async throws -> QueryResult { QueryResult(columns: [], rows: []) }
        func insert(database _: String, table _: String, values _: [ColumnValue]) async throws {}
        func update(database _: String, table _: String, values _: [ColumnValue], key _: [ColumnValue]) async throws {}
        func delete(database _: String, table _: String, key _: [ColumnValue]) async throws {}
    }

    private func step() -> WriteStep {
        WriteStep(statement: DMLStatement(sql: "DELETE FROM `t` WHERE `id` = ?", binds: [.int(1)]), expectedAffected: 1)
    }

    func testCommitForwardsStepsToDriver() async throws {
        let driver = RecordingDriver()
        let executor = RelationalWriteExecutor(driver: driver, database: "shop")
        try await executor.commit([step()])
        XCTAssertEqual(driver.committedBatches.count, 1)
        XCTAssertEqual(driver.committedBatches.first?.count, 1)
        XCTAssertEqual(driver.committedDatabase, "shop")
    }

    func testEmptyCommitDoesNotCallDriver() async throws {
        let driver = RecordingDriver()
        try await RelationalWriteExecutor(driver: driver, database: "shop").commit([])
        XCTAssertTrue(driver.committedBatches.isEmpty)
    }

    func testReadOnlyConnectionRefusesCommit() async {
        let driver = RecordingDriver()
        driver.capabilitiesOverride = DriverCapabilities(canEditRows: false)
        let executor = RelationalWriteExecutor(driver: driver, database: "shop")
        do {
            try await executor.commit([step()])
            XCTFail("expected read-only refusal")
        } catch {
            XCTAssertTrue(driver.committedBatches.isEmpty)
        }
    }

    func testDefaultDriverBatchIsUnsupported() async {
        // Driver không override executeTransaction dùng default ném lỗi.
        let driver = UnsupportedDriver()
        do {
            try await driver.executeTransaction([step()], database: "x")
            XCTFail("expected unsupported error")
        } catch {}
    }

    private final class UnsupportedDriver: RelationalDriver, @unchecked Sendable {
        let kind: DatabaseKind = .postgres
        func ping() async throws {}
        func listDatabases() async throws -> [DatabaseInfo] { [] }
        func listTables(database _: String) async throws -> [TableInfo] { [] }
        func columns(database _: String, table _: String) async throws -> [ColumnInfo] { [] }
        func allColumns(database _: String) async throws -> [String: [String]] { [:] }
        func allColumnsDetailed(database _: String) async throws -> [String: [ColumnInfo]] { [:] }
        func indexes(database _: String, table _: String) async throws -> [IndexInfo] { [] }
        func foreignKeys(database _: String) async throws -> [ForeignKeyRelation] { [] }
        func query(_: String, database _: String?) async throws -> QueryResult { QueryResult(columns: [], rows: []) }
        func paginatedRows(database _: String, table _: String, limit _: Int, offset _: Int) async throws -> QueryResult {
            QueryResult(columns: [], rows: [])
        }
        func openSession() async throws {}
        func closeSession() async {}
        func runSelect(_: DMLStatement, database _: String?) async throws -> QueryResult { QueryResult(columns: [], rows: []) }
        func insert(database _: String, table _: String, values _: [ColumnValue]) async throws {}
        func update(database _: String, table _: String, values _: [ColumnValue], key _: [ColumnValue]) async throws {}
        func delete(database _: String, table _: String, key _: [ColumnValue]) async throws {}
    }
}
