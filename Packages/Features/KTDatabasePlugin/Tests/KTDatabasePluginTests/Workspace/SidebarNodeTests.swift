import XCTest
@testable import KTDatabasePlugin

final class SidebarNodeTests: XCTestCase {
    private func profile(_ name: String, kind: DatabaseKind = .mysql) -> ConnectionProfile {
        ConnectionProfile(name: name, kind: kind, host: "127.0.0.1", port: 3306, user: "root", database: "app")
    }

    func testNoSelectionShowsOnlyConnections() {
        let roots = SidebarNode.build(
            profiles: [profile("prod"), profile("staging")],
            selectedProfileID: nil,
            database: nil,
            objects: [],
            favorites: [],
            filter: ""
        )
        XCTAssertEqual(roots.count, 1)
        XCTAssertEqual(roots[0].kind, .connectionsHeader)
        XCTAssertEqual(roots[0].children.count, 2)
    }

    func testSelectionAddsTablesViewsQueriesGroups() {
        let pid = UUID()
        let objects = [
            TableInfo(name: "users"),
            TableInfo(name: "orders"),
            TableInfo(name: "active_users", isView: true),
        ]
        let favorites = [QueryFavorite(id: UUID(), name: "recent orders", sql: "SELECT 1", savedAt: Date())]
        let roots = SidebarNode.build(
            profiles: [profile("prod")],
            selectedProfileID: pid,
            database: "app",
            objects: objects,
            favorites: favorites,
            filter: ""
        )
        XCTAssertEqual(roots.map(\.kind), [.connectionsHeader, .tablesHeader, .viewsHeader, .queriesHeader])
        XCTAssertEqual(roots[1].children.count, 2)
        XCTAssertEqual(roots[1].title, "app · Tables")
        XCTAssertEqual(roots[2].children.count, 1)
        XCTAssertEqual(roots[3].children.count, 1)
    }

    func testFilterAppliesToConnectionsAndObjects() {
        let roots = SidebarNode.build(
            profiles: [profile("prod"), profile("staging")],
            selectedProfileID: UUID(),
            database: "app",
            objects: [TableInfo(name: "users"), TableInfo(name: "orders")],
            favorites: [],
            filter: "us"
        )
        XCTAssertEqual(roots[0].children.count, 0) // no connection name contains "us"
        XCTAssertEqual(roots[1].children.map(\.title), ["users"])
    }

    func testTableAndViewSameNameHaveDistinctIDs() {
        let roots = SidebarNode.build(
            profiles: [profile("prod")],
            selectedProfileID: UUID(),
            database: "app",
            objects: [TableInfo(name: "report"), TableInfo(name: "report", isView: true)],
            favorites: [],
            filter: ""
        )
        let tableID = roots[1].children[0].id
        let viewID = roots[2].children[0].id
        XCTAssertNotEqual(tableID, viewID)
        XCTAssertEqual(tableID, "tbl.app.report")
        XCTAssertEqual(viewID, "vw.app.report")
    }
}
