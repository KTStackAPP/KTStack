import XCTest
@testable import KTDatabasePlugin

final class GridSelectionModelTests: XCTestCase {
    func testSingleCell() {
        var selection = GridSelectionModel()
        selection.selectCell(row: 2, column: 3)
        XCTAssertEqual(selection.rowRange, 2...2)
        XCTAssertEqual(selection.columnRange, 3...3)
        XCTAssertTrue(selection.contains(row: 2, column: 3))
        XCTAssertFalse(selection.contains(row: 2, column: 4))
    }

    func testExtendNormalizesRectangle() {
        var selection = GridSelectionModel()
        selection.selectCell(row: 4, column: 5)
        selection.extend(toRow: 1, column: 2)
        XCTAssertEqual(selection.rowRange, 1...4)
        XCTAssertEqual(selection.columnRange, 2...5)
        XCTAssertEqual(selection.cells.count, 16)
        XCTAssertEqual(selection.cells.first, GridCell(row: 1, column: 2))
        XCTAssertEqual(selection.cells.last, GridCell(row: 4, column: 5))
    }

    func testExtendWithoutAnchorStartsSelection() {
        var selection = GridSelectionModel()
        selection.extend(toRow: 1, column: 1)
        XCTAssertEqual(selection.rowRange, 1...1)
    }

    func testSelectRowAndColumn() {
        var selection = GridSelectionModel()
        selection.selectRow(3, columnCount: 4)
        XCTAssertEqual(selection.columnRange, 0...3)
        XCTAssertEqual(selection.rowRange, 3...3)
        selection.selectColumn(2, rowCount: 10)
        XCTAssertEqual(selection.rowRange, 0...9)
        XCTAssertEqual(selection.columnRange, 2...2)
    }

    func testSelectAll() {
        var selection = GridSelectionModel()
        selection.selectAll(rowCount: 5, columnCount: 3)
        XCTAssertEqual(selection.cells.count, 15)
    }

    func testClear() {
        var selection = GridSelectionModel()
        selection.selectCell(row: 0, column: 0)
        selection.clear()
        XCTAssertTrue(selection.isEmpty)
        XCTAssertNil(selection.rowRange)
        XCTAssertTrue(selection.cells.isEmpty)
    }
}
