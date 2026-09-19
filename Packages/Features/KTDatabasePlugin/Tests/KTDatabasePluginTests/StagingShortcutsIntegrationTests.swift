import AppKit
import KTStackCore
import XCTest
@testable import KTDatabasePlugin

@MainActor
final class StagingShortcutsIntegrationTests: XCTestCase {
    func testTableViewShortcutsDispatchCallbacks() {
        let table = KTGridKeyHandlingTableView(frame: NSRect(x: 0, y: 0, width: 200, height: 200))
        let col = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("col"))
        table.addTableColumn(col)

        var newRecordCalled = false
        var commitCalled = false
        var undoCalled = false
        var copyCalled = false
        var pasteCalled = false
        var selectAllCalled = false
        var deleteRowCalledWith: Int?

        table.onStageNewRecord = { newRecordCalled = true }
        table.onCommitStaged = { commitCalled = true }
        table.onUndoStaged = { undoCalled = true }
        table.onCopySelection = { copyCalled = true }
        table.onPasteSelection = { pasteCalled = true }
        table.onSelectAllCells = { selectAllCalled = true }
        table.onStageDeleteRow = { row in deleteRowCalledWith = row }

        _ = table.performKeyEquivalent(with: makeCommandEvent(character: "n"))
        XCTAssertTrue(newRecordCalled)

        _ = table.performKeyEquivalent(with: makeCommandEvent(character: "s"))
        XCTAssertTrue(commitCalled)

        _ = table.performKeyEquivalent(with: makeCommandEvent(character: "z"))
        XCTAssertTrue(undoCalled)

        _ = table.performKeyEquivalent(with: makeCommandEvent(character: "c"))
        XCTAssertTrue(copyCalled)

        _ = table.performKeyEquivalent(with: makeCommandEvent(character: "v"))
        XCTAssertTrue(pasteCalled)

        _ = table.performKeyEquivalent(with: makeCommandEvent(character: "a"))
        XCTAssertTrue(selectAllCalled)
        let dataSource = ShortcutTestDataSource()
        table.dataSource = dataSource
        table.reloadData()

        table.setActiveCell(row: 0, column: 0)
        let deleteEvent = NSEvent.keyEvent(
            with: .keyDown,
            location: .zero,
            modifierFlags: [],
            timestamp: 0,
            windowNumber: 0,
            context: nil,
            characters: "\u{7f}",
            charactersIgnoringModifiers: "\u{7f}",
            isARepeat: false,
            keyCode: 51
        )!
        table.keyDown(with: deleteEvent)
        XCTAssertEqual(deleteRowCalledWith, 0)
    }

    func testViewModelStagingWorkflow() async {
        let driver = ShortcutTestDriver()
        let vm = DatabaseV2ViewModel(
            tools: FakeDatabaseTools(),
            makeDriver: { _, _ in driver }
        )
        await vm.connect(profile: .managedMySQL)
        vm.select(table: TableInfo(name: "users"))
        try? await Task.sleep(for: .milliseconds(100))

        XCTAssertFalse(vm.isDraftingInsert)
        vm.beginInsertDraft()
        XCTAssertTrue(vm.isDraftingInsert)
        XCTAssertEqual(vm.insertDraftRowIndex, 1)

        vm.deleteRowOrCancelDraft(row: 1)
        XCTAssertFalse(vm.isDraftingInsert)

        vm.stageDelete(row: 0)
        XCTAssertEqual(vm.pendingChangeCount, 1)

        vm.undoOrCancelDraft()
        XCTAssertEqual(vm.pendingChangeCount, 0)
    }
    func testTableViewMouseDownDismissesEditing() {
        let table = KTGridKeyHandlingTableView(frame: NSRect(x: 0, y: 0, width: 200, height: 200))
        let col = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("col"))
        table.addTableColumn(col)
        let dataSource = ShortcutTestDataSource()
        table.dataSource = dataSource
        table.reloadData()

        table.startEditing(row: 0, column: 0, selectAll: true)
        XCTAssertTrue(table.overlayEditor.isEditing)

        let clickEvent = NSEvent.mouseEvent(
            with: .leftMouseDown,
            location: NSPoint(x: 50, y: 10),
            modifierFlags: [],
            timestamp: 0,
            windowNumber: 0,
            context: nil,
            eventNumber: 1,
            clickCount: 1,
            pressure: 1.0
        )!
        table.mouseDown(with: clickEvent)
        XCTAssertFalse(table.overlayEditor.isEditing)
    }

    func testTypeToEditFiltersFunctionKeys() {
        let table = KTGridKeyHandlingTableView(frame: NSRect(x: 0, y: 0, width: 200, height: 200))
        let col = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("col"))
        table.addTableColumn(col)
        let dataSource = ShortcutTestDataSource()
        table.dataSource = dataSource
        table.reloadData()
        table.setActiveCell(row: 0, column: 0)

        let pageDownEvent = NSEvent.keyEvent(
            with: .keyDown,
            location: .zero,
            modifierFlags: [.function],
            timestamp: 0,
            windowNumber: 0,
            context: nil,
            characters: "\u{F72C}",
            charactersIgnoringModifiers: "\u{F72C}",
            isARepeat: false,
            keyCode: 121
        )!
        table.keyDown(with: pageDownEvent)
        XCTAssertFalse(table.overlayEditor.isEditing)
    }

    private func makeCommandEvent(character: String) -> NSEvent {
        NSEvent.keyEvent(
            with: .keyDown, location: .zero, modifierFlags: .command,
            timestamp: 0, windowNumber: 0, context: nil,
            characters: character, charactersIgnoringModifiers: character,
            isARepeat: false, keyCode: 0
        )!
    }
}

private final class ShortcutTestDriver: RelationalDriver, @unchecked Sendable {
    let kind: DatabaseKind = .mysql
    var capabilities: DriverCapabilities { DriverCapabilities(canEditRows: true) }

    func ping() async throws {}
    func listDatabases() async throws -> [DatabaseInfo] { [DatabaseInfo(name: "testdb")] }
    func listTables(database: String) async throws -> [TableInfo] { [TableInfo(name: "users")] }
    func columns(database: String, table: String) async throws -> [ColumnInfo] {
        [
            ColumnInfo(name: "id", dataType: "int", isNullable: false, isPrimaryKey: true),
            ColumnInfo(name: "name", dataType: "varchar", isNullable: true, isPrimaryKey: false)
        ]
    }
    func allColumns(database: String) async throws -> [String: [String]] { [:] }
    func allColumnsDetailed(database: String) async throws -> [String: [ColumnInfo]] { [:] }
    func indexes(database: String, table: String) async throws -> [IndexInfo] { [] }
    func foreignKeys(database: String) async throws -> [ForeignKeyRelation] { [] }
    func query(_ sql: String, database: String?) async throws -> QueryResult {
        QueryResult(
            columns: [ColumnMeta(name: "id", typeName: "int"), ColumnMeta(name: "name", typeName: "varchar")],
            rows: [[.int(1), .text("Alice")]]
        )
    }
    func paginatedRows(database: String, table: String, limit: Int, offset: Int) async throws -> QueryResult {
        QueryResult(
            columns: [ColumnMeta(name: "id", typeName: "int"), ColumnMeta(name: "name", typeName: "varchar")],
            rows: [[.int(1), .text("Alice")]]
        )
    }
    func openSession() async throws {}
    func closeSession() async {}
    func runSelect(_ statement: DMLStatement, database: String?) async throws -> QueryResult {
        QueryResult(columns: [], rows: [])
    }
    func insert(database: String, table: String, values: [ColumnValue]) async throws {}
    func update(database: String, table: String, values: [ColumnValue], key: [ColumnValue]) async throws {}
    func delete(database: String, table: String, key: [ColumnValue]) async throws {}
    func executeTransaction(_ steps: [WriteStep], database: String) async throws {}
}

private final class ShortcutTestDataSource: NSObject, NSTableViewDataSource {
    func numberOfRows(in tableView: NSTableView) -> Int { 1 }
}
