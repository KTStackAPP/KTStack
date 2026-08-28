import XCTest
@testable import KTDatabasePlugin

final class StagedTableEditorTests: XCTestCase {
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

    private let columns = [
        ColumnInfo(name: "id", dataType: "int", isNullable: false, isPrimaryKey: true),
        ColumnInfo(name: "name", dataType: "varchar(50)", isNullable: true, isPrimaryKey: false),
        ColumnInfo(name: "age", dataType: "int", isNullable: true, isPrimaryKey: false),
    ]

    private func makeEditor(_ driver: RecordingDriver) -> StagedTableEditor {
        StagedTableEditor(
            schema: "shop", table: "users", dialect: .forKind(.mysql),
            columns: columns, uniqueIndexes: [], driver: driver, database: "shop"
        )
    }

    private func row(id: Int64, name: Cell, age: Cell) -> [String: Cell] {
        ["id": .int(id), "name": name, "age": age]
    }

    func testStageUpdateCoercesAndSkipsNoOp() throws {
        let editor = makeEditor(RecordingDriver())
        let existing = row(id: 1, name: .text("ann"), age: .int(30))
        XCTAssertTrue(try editor.stageUpdate(row: existing, column: "age", edit: .value("31")))
        XCTAssertFalse(try editor.stageUpdate(row: existing, column: "name", edit: .value("ann")))
        XCTAssertEqual(editor.pendingCount, 1)
    }

    func testKeylessRowRefused() {
        let editor = makeEditor(RecordingDriver())
        let noKey = row(id: 1, name: .text("x"), age: .int(1))
        var missingPK = noKey
        missingPK["id"] = nil
        XCTAssertThrowsError(try editor.stageUpdate(row: missingPK, column: "name", edit: .value("y")))
    }

    func testCommitForwardsOneTransaction() async throws {
        let driver = RecordingDriver()
        let editor = makeEditor(driver)
        _ = try editor.stageUpdate(row: row(id: 1, name: .text("ann"), age: .int(30)), column: "age", edit: .value("31"))
        try editor.stageDelete(row: row(id: 2, name: .text("bob"), age: .int(40)))
        try await editor.commit()
        XCTAssertEqual(driver.committedBatches.count, 1)
        XCTAssertEqual(driver.committedBatches.first?.count, 2)
        XCTAssertFalse(editor.hasPendingChanges)
    }

    func testUndoRedoAcrossStages() throws {
        let editor = makeEditor(RecordingDriver())
        _ = try editor.stageUpdate(row: row(id: 1, name: .text("ann"), age: .int(30)), column: "age", edit: .value("31"))
        XCTAssertEqual(editor.pendingCount, 1)
        editor.undo()
        XCTAssertFalse(editor.hasPendingChanges)
        editor.redo()
        XCTAssertEqual(editor.pendingCount, 1)
    }

    func testDeleteThenCommitEmptiesBuffer() async throws {
        let driver = RecordingDriver()
        let editor = makeEditor(driver)
        try editor.stageDelete(row: row(id: 3, name: .null, age: .null))
        XCTAssertTrue(editor.hasPendingChanges)
        try await editor.commit()
        XCTAssertFalse(editor.hasPendingChanges)
        XCTAssertFalse(editor.canUndo)
    }

    func testApplyPasteStagesUpdates() throws {
        let editor = makeEditor(RecordingDriver())
        let rows = [
            row(id: 1, name: .text("ann"), age: .int(30)),
            row(id: 2, name: .text("bob"), age: .int(40)),
        ]
        let cells = [
            PastedCell(row: 0, column: 1, value: "ANN"),
            PastedCell(row: 1, column: 2, value: "41"),
        ]
        let staged = try editor.applyPaste(cells, rows: rows, columnNames: ["id", "name", "age"])
        XCTAssertEqual(staged, 2)
        XCTAssertEqual(editor.pendingCount, 2)
    }

    func testSqlPreviewIsRedacted() throws {
        let editor = makeEditor(RecordingDriver())
        _ = try editor.stageUpdate(row: row(id: 1, name: .text("ann"), age: .int(30)), column: "name", edit: .value("secret"))
        let preview = try editor.sqlPreview()
        XCTAssertEqual(preview.statements.count, 1)
        XCTAssertFalse(preview.statements[0].contains("secret"))
        XCTAssertTrue(preview.statements[0].contains("?"))
    }

    func testReadOnlyDriverRefusesCommit() async throws {
        let driver = RecordingDriver()
        driver.capabilitiesOverride = DriverCapabilities(canEditRows: false)
        let editor = makeEditor(driver)
        _ = try editor.stageUpdate(row: row(id: 1, name: .text("ann"), age: .int(30)), column: "age", edit: .value("31"))
        do {
            try await editor.commit()
            XCTFail("expected read-only refusal")
        } catch {
            XCTAssertTrue(driver.committedBatches.isEmpty)
            XCTAssertTrue(editor.hasPendingChanges)
        }
    }

    func testStageDefaultEmitsUnboundDefaultKeyword() throws {
        let editor = makeEditor(RecordingDriver())
        XCTAssertTrue(try editor.stageUpdate(row: row(id: 1, name: .text("ann"), age: .int(30)), column: "age", edit: .default))
        let preview = try editor.sqlPreview()
        XCTAssertEqual(preview.statements.count, 1)
        XCTAssertTrue(preview.statements[0].contains("`age` = DEFAULT"))
        XCTAssertEqual(preview.bindCount, 1) // chỉ còn bind của key
    }

    func testStageDefaultAfterValueOnSameColumnKeepsDefaultOnly() throws {
        let editor = makeEditor(RecordingDriver())
        let existing = row(id: 1, name: .text("ann"), age: .int(30))
        _ = try editor.stageUpdate(row: existing, column: "age", edit: .value("31"))
        _ = try editor.stageUpdate(row: existing, column: "age", edit: .default)
        let preview = try editor.sqlPreview()
        XCTAssertTrue(preview.statements[0].contains("`age` = DEFAULT"))
        XCTAssertFalse(preview.statements[0].contains("`age` = ?"))
        XCTAssertEqual(editor.pendingCount, 1)
    }
}
