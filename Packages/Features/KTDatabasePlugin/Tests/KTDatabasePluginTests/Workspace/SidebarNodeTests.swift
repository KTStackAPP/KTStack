import XCTest
@testable import KTDatabasePlugin

final class SidebarNodeTests: XCTestCase {
    func testAlwaysThreeGroupsWithCounts() {
        let roots = SidebarNode.build(objects: [], favorites: [], filter: "")
        XCTAssertEqual(roots.map(\.kind), [.tablesHeader, .viewsHeader, .queriesHeader])
        XCTAssertEqual(roots.map(\.subtitle), ["0", "0", "0"])
        XCTAssertTrue(roots.allSatisfy(\.isGroup))
    }

    func testGroupsCarryObjectsAndCounts() {
        let objects = [
            TableInfo(name: "users"),
            TableInfo(name: "orders"),
            TableInfo(name: "active_users", isView: true),
        ]
        let favorites = [QueryFavorite(id: UUID(), name: "recent orders", sql: "SELECT 1", savedAt: Date())]
        let roots = SidebarNode.build(objects: objects, favorites: favorites, filter: "")
        XCTAssertEqual(roots[0].children.count, 2)
        XCTAssertEqual(roots[0].subtitle, "2")
        XCTAssertEqual(roots[1].children.count, 1)
        XCTAssertEqual(roots[2].children.count, 1)
    }

    func testFilterAppliesOnlyToChildren() {
        let roots = SidebarNode.build(
            objects: [TableInfo(name: "users"), TableInfo(name: "orders")],
            favorites: [],
            filter: "us"
        )
        XCTAssertEqual(roots[0].children.map(\.title), ["users"])
        XCTAssertEqual(roots[0].subtitle, "1")
    }

    func testTableAndViewSameNameHaveDistinctIDs() {
        let roots = SidebarNode.build(
            objects: [TableInfo(name: "report"), TableInfo(name: "report", isView: true)],
            favorites: [],
            filter: ""
        )
        let tableID = roots[0].children[0].id
        let viewID = roots[1].children[0].id
        XCTAssertNotEqual(tableID, viewID)
        XCTAssertEqual(tableID, "tbl.report")
        XCTAssertEqual(viewID, "vw.report")
    }
}
