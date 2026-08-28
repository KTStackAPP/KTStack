import XCTest
@testable import KTDatabasePlugin

final class GridPaginationStateTests: XCTestCase {
    func testOffsetFollowsPage() {
        var state = GridPaginationState(pageSize: 50)
        XCTAssertEqual(state.offset, 0)
        state.next()
        XCTAssertEqual(state.offset, 50)
    }

    func testPageCountRoundsUp() {
        let state = GridPaginationState(pageSize: 100, total: .exact(250))
        XCTAssertEqual(state.pageCount, 3)
    }

    func testEmptyTableIsOnePage() {
        let state = GridPaginationState(pageSize: 100, total: .exact(0))
        XCTAssertEqual(state.pageCount, 1)
    }

    func testNavigationClampsWithKnownTotal() {
        var state = GridPaginationState(pageSize: 100, total: .exact(250))
        state.last()
        XCTAssertEqual(state.page, 2)
        XCTAssertFalse(state.hasNext)
        state.next()
        XCTAssertEqual(state.page, 2)
        state.first()
        XCTAssertEqual(state.page, 0)
        XCTAssertFalse(state.hasPrevious)
        state.previous()
        XCTAssertEqual(state.page, 0)
    }

    func testUnknownTotalAllowsNextButNotLast() {
        var state = GridPaginationState(pageSize: 100, total: .unknown)
        XCTAssertNil(state.pageCount)
        XCTAssertTrue(state.hasNext)
        state.next()
        XCTAssertEqual(state.page, 1)
        state.last()
        XCTAssertEqual(state.page, 1)
    }

    func testSetPageSizeResetsToFirstPage() {
        var state = GridPaginationState(pageSize: 100, page: 3, total: .exact(1000))
        state.setPageSize(25)
        XCTAssertEqual(state.pageSize, 25)
        XCTAssertEqual(state.page, 0)
    }

    func testEstimatedTotalDrivesPageCount() {
        let state = GridPaginationState(pageSize: 100, total: .estimated(150))
        XCTAssertEqual(state.pageCount, 2)
        XCTAssertEqual(state.total.value, 150)
    }
}
