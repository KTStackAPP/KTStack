import XCTest
@testable import KTDatabasePlugin

final class GridSortDescriptorTests: XCTestCase {
    func testCycleAddsAscendingThenDescendingThenRemoves() {
        var sort = GridSortDescriptor()
        sort.cycle("name")
        XCTAssertEqual(sort.direction(for: "name"), true)
        sort.cycle("name")
        XCTAssertEqual(sort.direction(for: "name"), false)
        sort.cycle("name")
        XCTAssertNil(sort.direction(for: "name"))
        XCTAssertTrue(sort.isEmpty)
    }

    func testClickOrderIsPriority() {
        var sort = GridSortDescriptor()
        sort.cycle("a")
        sort.cycle("b")
        XCTAssertEqual(sort.priority(of: "a"), 0)
        XCTAssertEqual(sort.priority(of: "b"), 1)
        XCTAssertEqual(sort.specs.map(\.column), ["a", "b"])
    }

    func testCyclingKeepsPositionOnDirectionFlip() {
        var sort = GridSortDescriptor()
        sort.cycle("a")
        sort.cycle("b")
        sort.cycle("a")
        XCTAssertEqual(sort.priority(of: "a"), 0)
        XCTAssertEqual(sort.direction(for: "a"), false)
    }

    func testRemovingMiddleColumnCompactsPriority() {
        var sort = GridSortDescriptor()
        sort.cycle("a")
        sort.cycle("b")
        sort.cycle("c")
        sort.cycle("b")
        sort.cycle("b")
        XCTAssertEqual(sort.specs.map(\.column), ["a", "c"])
        XCTAssertEqual(sort.priority(of: "c"), 1)
    }

    func testClearRemovesEverything() {
        var sort = GridSortDescriptor(specs: [SortSpec(column: "x", ascending: true)])
        sort.clear()
        XCTAssertTrue(sort.isEmpty)
    }
}
