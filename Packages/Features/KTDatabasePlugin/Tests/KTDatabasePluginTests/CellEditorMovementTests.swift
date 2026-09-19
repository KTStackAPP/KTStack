import XCTest
@testable import KTDatabasePlugin

final class CellEditorMovementTests: XCTestCase {
    func testMovementEnumCases() {
        let movements: [KTCellEditorMovement] = [.tab, .backtab, .up, .down]
        XCTAssertEqual(movements.count, 4)
        XCTAssertNotEqual(KTCellEditorMovement.tab, KTCellEditorMovement.backtab)
        XCTAssertNotEqual(KTCellEditorMovement.up, KTCellEditorMovement.down)

        var set: Set<KTCellEditorMovement> = []
        set.insert(.tab)
        set.insert(.backtab)
        set.insert(.up)
        set.insert(.down)
        XCTAssertEqual(set.count, 4)
    }

    func testCanExitUpSingleLine() {
        let text = "Hello World"
        XCTAssertTrue(KTCellEditorArrowExit.canExitUp(text: "", selectedRange: NSRange(location: 0, length: 0)))
        XCTAssertTrue(KTCellEditorArrowExit.canExitUp(text: text, selectedRange: NSRange(location: 0, length: 0)))
        XCTAssertTrue(KTCellEditorArrowExit.canExitUp(text: text, selectedRange: NSRange(location: 5, length: 0)))
        XCTAssertTrue(KTCellEditorArrowExit.canExitUp(text: text, selectedRange: NSRange(location: 11, length: 0)))
    }

    func testCanExitDownSingleLine() {
        let text = "Hello World"
        XCTAssertTrue(KTCellEditorArrowExit.canExitDown(text: "", selectedRange: NSRange(location: 0, length: 0)))
        XCTAssertTrue(KTCellEditorArrowExit.canExitDown(text: text, selectedRange: NSRange(location: 0, length: 0)))
        XCTAssertTrue(KTCellEditorArrowExit.canExitDown(text: text, selectedRange: NSRange(location: 5, length: 0)))
        XCTAssertTrue(KTCellEditorArrowExit.canExitDown(text: text, selectedRange: NSRange(location: 11, length: 0)))
    }

    func testCanExitUpMultiLine() {
        let text = "Line 1\nLine 2\nLine 3"
        XCTAssertTrue(KTCellEditorArrowExit.canExitUp(text: text, selectedRange: NSRange(location: 0, length: 0)))
        XCTAssertTrue(KTCellEditorArrowExit.canExitUp(text: text, selectedRange: NSRange(location: 5, length: 0)))
        XCTAssertTrue(KTCellEditorArrowExit.canExitUp(text: text, selectedRange: NSRange(location: 6, length: 0)))

        XCTAssertFalse(KTCellEditorArrowExit.canExitUp(text: text, selectedRange: NSRange(location: 7, length: 0)))
        XCTAssertFalse(KTCellEditorArrowExit.canExitUp(text: text, selectedRange: NSRange(location: 10, length: 0)))
        XCTAssertFalse(KTCellEditorArrowExit.canExitUp(text: text, selectedRange: NSRange(location: 15, length: 0)))
    }

    func testCanExitDownMultiLine() {
        let text = "Line 1\nLine 2\nLine 3"
        XCTAssertFalse(KTCellEditorArrowExit.canExitDown(text: text, selectedRange: NSRange(location: 0, length: 0)))
        XCTAssertFalse(KTCellEditorArrowExit.canExitDown(text: text, selectedRange: NSRange(location: 6, length: 0)))
        XCTAssertFalse(KTCellEditorArrowExit.canExitDown(text: text, selectedRange: NSRange(location: 10, length: 0)))

        XCTAssertTrue(KTCellEditorArrowExit.canExitDown(text: text, selectedRange: NSRange(location: 14, length: 0)))
        XCTAssertTrue(KTCellEditorArrowExit.canExitDown(text: text, selectedRange: NSRange(location: 18, length: 0)))
        XCTAssertTrue(KTCellEditorArrowExit.canExitDown(text: text, selectedRange: NSRange(location: 20, length: 0)))
    }
}
