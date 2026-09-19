import XCTest
@testable import KTDatabasePlugin

final class CellMovementCoordinatorTests: XCTestCase {
    func testTabWithinRow() {
        let next = KTCellMovementCoordinator.nextCell(
            from: (row: 0, column: 1),
            movement: .tab,
            rowCount: 3,
            columnCount: 3
        )
        XCTAssertEqual(next?.row, 0)
        XCTAssertEqual(next?.column, 2)
    }

    func testTabWrapAround() {
        let next = KTCellMovementCoordinator.nextCell(
            from: (row: 0, column: 2),
            movement: .tab,
            rowCount: 3,
            columnCount: 3
        )
        XCTAssertEqual(next?.row, 1)
        XCTAssertEqual(next?.column, 0)
    }

    func testTabAtTableEnd() {
        let next = KTCellMovementCoordinator.nextCell(
            from: (row: 2, column: 2),
            movement: .tab,
            rowCount: 3,
            columnCount: 3
        )
        XCTAssertNil(next)
    }

    func testBacktabWithinRow() {
        let next = KTCellMovementCoordinator.nextCell(
            from: (row: 1, column: 2),
            movement: .backtab,
            rowCount: 3,
            columnCount: 3
        )
        XCTAssertEqual(next?.row, 1)
        XCTAssertEqual(next?.column, 1)
    }

    func testBacktabWrapAround() {
        let next = KTCellMovementCoordinator.nextCell(
            from: (row: 1, column: 0),
            movement: .backtab,
            rowCount: 3,
            columnCount: 3
        )
        XCTAssertEqual(next?.row, 0)
        XCTAssertEqual(next?.column, 2)
    }

    func testBacktabAtTableStart() {
        let next = KTCellMovementCoordinator.nextCell(
            from: (row: 0, column: 0),
            movement: .backtab,
            rowCount: 3,
            columnCount: 3
        )
        XCTAssertNil(next)
    }

    func testUpMovement() {
        let next = KTCellMovementCoordinator.nextCell(
            from: (row: 2, column: 1),
            movement: .up,
            rowCount: 3,
            columnCount: 3
        )
        XCTAssertEqual(next?.row, 1)
        XCTAssertEqual(next?.column, 1)

        let top = KTCellMovementCoordinator.nextCell(
            from: (row: 0, column: 1),
            movement: .up,
            rowCount: 3,
            columnCount: 3
        )
        XCTAssertNil(top)
    }

    func testDownMovement() {
        let next = KTCellMovementCoordinator.nextCell(
            from: (row: 0, column: 1),
            movement: .down,
            rowCount: 3,
            columnCount: 3
        )
        XCTAssertEqual(next?.row, 1)
        XCTAssertEqual(next?.column, 1)

        let bottom = KTCellMovementCoordinator.nextCell(
            from: (row: 2, column: 1),
            movement: .down,
            rowCount: 3,
            columnCount: 3
        )
        XCTAssertNil(bottom)
    }

    func testEmptyTable() {
        let next = KTCellMovementCoordinator.nextCell(
            from: (row: 0, column: 0),
            movement: .tab,
            rowCount: 0,
            columnCount: 0
        )
        XCTAssertNil(next)
    }
}
