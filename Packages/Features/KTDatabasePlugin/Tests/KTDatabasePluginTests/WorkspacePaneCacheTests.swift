import XCTest
@testable import KTDatabasePlugin

final class WorkspacePaneCacheTests: XCTestCase {
    func testTouchUnderLimitEvictsNothing() {
        var cache = WorkspacePaneCache(limit: 3)
        let ids = (0..<3).map { _ in UUID() }
        for id in ids {
            XCTAssertEqual(cache.touch(id), [])
        }
        XCTAssertEqual(cache.order, ids)
    }

    func testOverLimitEvictsLeastRecentlyUsed() {
        var cache = WorkspacePaneCache(limit: 2)
        let a = UUID(), b = UUID(), c = UUID()
        _ = cache.touch(a)
        _ = cache.touch(b)
        _ = cache.touch(a)
        XCTAssertEqual(cache.touch(c), [b])
        XCTAssertEqual(cache.order, [a, c])
    }

    func testJustTouchedIDIsNeverEvicted() {
        var cache = WorkspacePaneCache(limit: 1)
        let a = UUID(), b = UUID()
        _ = cache.touch(a)
        XCTAssertEqual(cache.touch(b), [a])
        XCTAssertEqual(cache.order, [b])
    }

    func testRetainReturnsClosedIDs() {
        var cache = WorkspacePaneCache(limit: 4)
        let a = UUID(), b = UUID(), c = UUID()
        [a, b, c].forEach { _ = cache.touch($0) }
        XCTAssertEqual(cache.retain([a, c]), [b])
        XCTAssertEqual(cache.order, [a, c])
    }

    func testLimitBelowOneIsClampedToOne() {
        XCTAssertEqual(WorkspacePaneCache(limit: 0).limit, 1)
    }
}
