import XCTest
@testable import KTDatabasePlugin

final class GridPasteParserTests: XCTestCase {
    func testParseTSV() throws {
        let grid = try GridPasteParser.parseTSV("a\tb\nc\td\n")
        XCTAssertEqual(grid.rows, [["a", "b"], ["c", "d"]])
        XCTAssertEqual(grid.height, 2)
        XCTAssertEqual(grid.width, 2)
    }

    func testRaggedTSVRejected() {
        XCTAssertThrowsError(try GridPasteParser.parseTSV("a\tb\nc")) { error in
            XCTAssertEqual(error as? GridPasteError, .ragged)
        }
    }

    func testParseCSVWithQuotedFields() throws {
        let grid = try GridPasteParser.parseCSV("1,\"a,b\",\"line\nbreak\"\r\n2,x,y")
        XCTAssertEqual(grid.rows, [["1", "a,b", "line\nbreak"], ["2", "x", "y"]])
    }

    func testParseCSVEscapedQuote() throws {
        let grid = try GridPasteParser.parseCSV("\"O\"\"Hara\",2")
        XCTAssertEqual(grid.rows, [["O\"Hara", "2"]])
    }

    func testResolveSingleCellFillsTarget() throws {
        let grid = PasteGrid(rows: [["X"]])
        let edits = try GridPasteParser.resolve(grid, into: PasteTarget(
            anchorRow: 0, anchorColumn: 0, targetRows: 2, targetColumns: 2, gridRowCount: 5, gridColumnCount: 5
        ))
        XCTAssertEqual(edits.count, 4)
        XCTAssertTrue(edits.allSatisfy { $0.value == "X" })
    }

    func testResolveExactShapeMatch() throws {
        let grid = PasteGrid(rows: [["a", "b"], ["c", "d"]])
        let edits = try GridPasteParser.resolve(grid, into: PasteTarget(
            anchorRow: 1, anchorColumn: 1, targetRows: 2, targetColumns: 2, gridRowCount: 5, gridColumnCount: 5
        ))
        XCTAssertEqual(edits.count, 4)
        XCTAssertEqual(edits.first, PastedCell(row: 1, column: 1, value: "a"))
        XCTAssertEqual(edits.last, PastedCell(row: 2, column: 2, value: "d"))
    }

    func testResolveShapeMismatchRejected() {
        let grid = PasteGrid(rows: [["a", "b", "c"]])
        XCTAssertThrowsError(try GridPasteParser.resolve(grid, into: PasteTarget(
            anchorRow: 0, anchorColumn: 0, targetRows: 2, targetColumns: 2, gridRowCount: 5, gridColumnCount: 5
        ))) { error in
            guard case .shapeMismatch = (error as? GridPasteError) else { return XCTFail("expected shapeMismatch") }
        }
    }

    func testResolveOutOfBoundsRejected() {
        let grid = PasteGrid(rows: [["a", "b"], ["c", "d"]])
        XCTAssertThrowsError(try GridPasteParser.resolve(grid, into: PasteTarget(
            anchorRow: 4, anchorColumn: 4, targetRows: 2, targetColumns: 2, gridRowCount: 5, gridColumnCount: 5
        ))) { error in
            XCTAssertEqual(error as? GridPasteError, .outOfBounds)
        }
    }

    func testSingleCellIntoSingleCellTarget() throws {
        let grid = PasteGrid(rows: [["only"]])
        let edits = try GridPasteParser.resolve(grid, into: PasteTarget(
            anchorRow: 0, anchorColumn: 0, targetRows: 1, targetColumns: 1, gridRowCount: 3, gridColumnCount: 3
        ))
        XCTAssertEqual(edits, [PastedCell(row: 0, column: 0, value: "only")])
    }
}
