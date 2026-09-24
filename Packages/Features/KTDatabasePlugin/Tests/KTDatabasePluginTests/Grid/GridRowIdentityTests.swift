import AppKit
import XCTest
@testable import KTDatabasePlugin

@MainActor
final class GridRowIdentityTests: XCTestCase {
    private var current: QueryResult!
    private var committed: [(ref: GridRowRef, column: String, text: String)] = []

    private static func page(_ ids: [Int64]) -> QueryResult {
        QueryResult(
            columns: [ColumnMeta(name: "id"), ColumnMeta(name: "name")],
            rows: ids.map { [Cell.int($0), Cell.text("n\($0)")] }
        )
    }

    private func makeGrid(windowStart: Int) -> (KTDataGrid.Coordinator, KTGridKeyHandlingTableView) {
        current = Self.page([1, 2, 3, 4, 5])
        let coordinator = KTDataGrid.Coordinator(result: current)
        let table = KTGridKeyHandlingTableView(frame: NSRect(x: 0, y: 0, width: 400, height: 400))
        table.dataSource = coordinator
        table.delegate = coordinator
        coordinator.table = table
        coordinator.rebuildColumns(for: current)
        coordinator.rowNumberOffset = windowStart
        coordinator.lastRowNumberOffset = windowStart
        table.reloadData()
        table.onBeginEditing = { [weak coordinator] row, col in coordinator?.beginEditing(row: row, column: col) }
        table.onCommitCell = { [weak coordinator] row, col, text in coordinator?.commitEdit(row: row, column: col, text: text) }
        coordinator.rowRef = { [unowned self] row in
            .row(table: "users", values: ["id": self.current.rows[row][0]])
        }
        coordinator.onCommitRowEdit = { [unowned self] ref, column, text in
            self.committed.append((ref, column, text))
        }
        return (coordinator, table)
    }

    func testOverlayCommitsToTheRowItWasOpenedOnWhenRowsArePrepended() async throws {
        let (coordinator, table) = makeGrid(windowStart: 3)
        table.startEditing(row: 1, column: 2, initialCharacter: "x")
        XCTAssertTrue(table.overlayEditor.isEditing)

        current = Self.page([101, 102, 103, 1, 2, 3, 4, 5])
        coordinator.rowNumberOffset = 0
        coordinator.apply(current)

        XCTAssertFalse(table.overlayEditor.isEditing)
        try await Task.sleep(for: .milliseconds(50))
        XCTAssertEqual(committed.count, 1)
        XCTAssertEqual(committed.first?.ref, .row(table: "users", values: ["id": .int(2)]))
        XCTAssertEqual(committed.first?.column, "name")
    }

    func testActiveCellFollowsItsRowWhenTheWindowShifts() {
        let (coordinator, table) = makeGrid(windowStart: 3)
        table.setActiveCell(row: 1, column: 2)

        current = Self.page([101, 102, 103, 1, 2, 3, 4, 5])
        coordinator.rowNumberOffset = 0
        coordinator.apply(current)

        XCTAssertEqual(table.activeCell?.row, 4)
        XCTAssertEqual(table.activeCell?.column, 2)
    }

    func testActiveCellClearsWhenItsRowLeavesTheWindow() {
        let (coordinator, table) = makeGrid(windowStart: 0)
        table.setActiveCell(row: 0, column: 1)

        current = Self.page([3, 4, 5, 6, 7])
        coordinator.rowNumberOffset = 2
        coordinator.apply(current)

        XCTAssertNil(table.activeCell)
    }

    func testEditingAnotherCellCommitsThePreviousCellToItsOwnRow() {
        let (coordinator, table) = makeGrid(windowStart: 0)
        table.startEditing(row: 0, column: 2, initialCharacter: "x")
        table.startEditing(row: 3, column: 2)
        XCTAssertTrue(coordinator.editingRef != nil)
        XCTAssertEqual(committed.map { $0.ref }, [.row(table: "users", values: ["id": .int(1)])])
    }

    func testShiftedRowStaysInsideTheWindow() {
        XCTAssertEqual(KTGridKeyHandlingTableView.shiftedRow(1, by: 3, rowCount: 8), 4)
        XCTAssertNil(KTGridKeyHandlingTableView.shiftedRow(1, by: -2, rowCount: 8))
        XCTAssertNil(KTGridKeyHandlingTableView.shiftedRow(6, by: 3, rowCount: 8))
    }
}
