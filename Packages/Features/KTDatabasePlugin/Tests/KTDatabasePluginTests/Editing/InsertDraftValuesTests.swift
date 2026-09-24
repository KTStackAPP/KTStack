import XCTest
@testable import KTDatabasePlugin

final class InsertDraftValuesTests: XCTestCase {
    private final class RecordingDriver: RelationalDriver, @unchecked Sendable {
        let kind: DatabaseKind = .mysql
        var capabilitiesOverride = DriverCapabilities(canEditRows: true)
        var capabilities: DriverCapabilities { capabilitiesOverride }
        private(set) var committedBatches: [[WriteStep]] = []

        func executeTransaction(_ steps: [WriteStep], database _: String) async throws {
            committedBatches.append(steps)
        }

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

    func testDefaultColumnsStayDefaultInsteadOfNull() {
        let buffer = GridEditBuffer()
        let id = buffer.stageInsert()
        buffer.setDraftValue(id, column: "name", value: .text("ann"))
        buffer.setDraftDefault(id, column: "created_at")

        guard case let .insert(values)? = buffer.operations().first else { return XCTFail("expected an insert") }
        XCTAssertEqual(values.first { $0.column == "created_at" }?.isDefault, true)
    }

    func testCommittedInsertSendsDefaultKeywordNotNull() async throws {
        let driver = RecordingDriver()
        let editor = StagedTableEditor(
            schema: "shop", table: "users", dialect: .forKind(.mysql),
            columns: [
                ColumnInfo(name: "id", dataType: "int", isNullable: false, isPrimaryKey: true),
                ColumnInfo(name: "created_at", dataType: "timestamp", isNullable: false, isPrimaryKey: false),
            ],
            uniqueIndexes: [], driver: driver, database: "shop"
        )
        editor.stageInsert(values: [ColumnValue(column: "id", value: .int(1)), ColumnValue(defaultFor: "created_at")])
        try await editor.commit()

        let statement = try XCTUnwrap(driver.committedBatches.first?.first?.statement)
        XCTAssertTrue(statement.sql.contains("DEFAULT"), statement.sql)
        XCTAssertFalse(statement.binds.contains(.null))
    }
}
