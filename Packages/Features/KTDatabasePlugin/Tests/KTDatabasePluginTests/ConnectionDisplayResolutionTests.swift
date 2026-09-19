import XCTest
@testable import KTDatabasePlugin

final class ConnectionDisplayResolutionTests: XCTestCase {
    func testCustomNameTakesPrecedence() {
        let profile = ConnectionProfile(
            name: "Shop Production",
            kind: .mysql,
            host: "127.0.0.1",
            port: 3306,
            user: "root",
            database: "shop"
        )
        XCTAssertEqual(profile.displayTitle(), "Shop Production")
        XCTAssertEqual(profile.displaySubtitle(), "MySQL · shop · 127.0.0.1:3306")
    }

    func testHostNameFallbackToDatabase() {
        let profile = ConnectionProfile(
            name: "127.0.0.1",
            kind: .mysql,
            host: "127.0.0.1",
            port: 3306,
            user: "root",
            database: "1985blender"
        )
        XCTAssertEqual(profile.displayTitle(), "1985blender")
        XCTAssertEqual(profile.displaySubtitle(), "MySQL · 127.0.0.1:3306")
    }

    func testHostNameFallbackToLocalEngineName() {
        let profile = ConnectionProfile(
            name: "127.0.0.1",
            kind: .mysql,
            host: "127.0.0.1",
            port: 3306,
            user: "root",
            database: ""
        )
        XCTAssertEqual(profile.displayTitle(lastUsedDatabase: "shop_wp"), "Local MySQL")
        XCTAssertEqual(profile.displaySubtitle(lastUsedDatabase: "shop_wp"), "MySQL · 127.0.0.1:3306 · Last: shop_wp")
    }

    func testEmptyDatabaseFallbackToEngineName() {
        let profile = ConnectionProfile(
            name: "127.0.0.1",
            kind: .mysql,
            host: "127.0.0.1",
            port: 3306,
            user: "root",
            database: ""
        )
        XCTAssertEqual(profile.displayTitle(), "Local MySQL")
        XCTAssertEqual(profile.displaySubtitle(), "MySQL · 127.0.0.1:3306")
    }

    func testSQLiteDisplayTitleAndSubtitle() {
        let profile = ConnectionProfile(
            name: "",
            kind: .sqlite,
            host: "",
            port: 0,
            user: "",
            database: "main",
            filePath: "/tmp/sample.sqlite"
        )
        XCTAssertEqual(profile.displayTitle(), "sample.sqlite")
        XCTAssertEqual(profile.displaySubtitle(), "/tmp/sample.sqlite")
    }

    func testRecentDatabasesUniqueAndOrdered() {
        let dir = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("kd-recent-db-\(UUID().uuidString)", isDirectory: true)
        let fm = FileManager.default
        try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
        let url = dir.appendingPathComponent("workspace-recent.json")
        defer { try? fm.removeItem(at: dir) }

        let store = RecentObjectStore(storeURL: url)
        let pid1 = UUID()
        let pid2 = UUID()

        store.record(RecentObject(profileID: pid1, database: "db_first", name: "table_a", isView: false))
        store.record(RecentObject(profileID: pid1, database: "db_second", name: "table_b", isView: false))
        store.record(RecentObject(profileID: pid1, database: "db_first", name: "table_c", isView: false))
        store.record(RecentObject(profileID: pid2, database: "db_other", name: "table_d", isView: false))

        let recentsForPid1 = store.recentDatabases(for: pid1)
        XCTAssertEqual(recentsForPid1, ["db_first", "db_second"])

        let recentsForPid2 = store.recentDatabases(for: pid2)
        XCTAssertEqual(recentsForPid2, ["db_other"])
    }
}
