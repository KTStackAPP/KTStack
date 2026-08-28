import XCTest
@testable import KTDatabasePlugin

/// Engine-free coverage of the ordered result session: pin retention across runs, close-picks-neighbor,
/// select and active tracking.
final class QueryResultSessionTests: XCTestCase {
    private func item(_ label: String, pinned: Bool = false) -> QueryResultItem {
        QueryResultItem(label: label, statement: label, isPinned: pinned)
    }

    func testAppendSetsFirstActive() {
        var session = QueryResultSession.empty
        let a = item("A")
        session.append(a)
        session.append(item("B"))
        XCTAssertEqual(session.activeItem?.id, a.id)
        XCTAssertEqual(session.items.count, 2)
    }

    func testBeginRunDropsUnpinnedKeepsPinned() {
        var session = QueryResultSession.empty
        session.append(item("A", pinned: true))
        session.append(item("B"))
        session.beginRun()
        XCTAssertEqual(session.items.map(\.label), ["A"])
        XCTAssertNil(session.activeItemID)
    }

    func testCloseActivePicksNeighbor() {
        var session = QueryResultSession.empty
        let a = item("A"); let b = item("B"); let c = item("C")
        session.append(a); session.append(b); session.append(c)
        session.select(b.id)
        session.close(b.id)
        XCTAssertEqual(session.activeItem?.label, "C")
        XCTAssertEqual(session.items.map(\.label), ["A", "C"])
    }

    func testCloseLastActiveFallsBack() {
        var session = QueryResultSession.empty
        let a = item("A"); let b = item("B")
        session.append(a); session.append(b)
        session.select(b.id)
        session.close(b.id)
        XCTAssertEqual(session.activeItem?.label, "A")
    }

    func testTogglePin() {
        var session = QueryResultSession.empty
        let a = item("A")
        session.append(a)
        session.togglePin(a.id)
        XCTAssertTrue(session.items.first?.isPinned ?? false)
        session.togglePin(a.id)
        XCTAssertFalse(session.items.first?.isPinned ?? true)
    }

    func testTruncatedByCapFlag() {
        let capped = QueryResultItem(
            label: "R", statement: "SELECT 1",
            result: QueryResult(columns: [ColumnMeta(name: "x")], rows: [], truncated: true),
            capApplied: true
        )
        XCTAssertTrue(capped.isTruncatedByCap)
        let uncapped = QueryResultItem(
            label: "R", statement: "SELECT 1",
            result: QueryResult(columns: [ColumnMeta(name: "x")], rows: [], truncated: true),
            capApplied: false
        )
        XCTAssertFalse(uncapped.isTruncatedByCap)
    }
}
