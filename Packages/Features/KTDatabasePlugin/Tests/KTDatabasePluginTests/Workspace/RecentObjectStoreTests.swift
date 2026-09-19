import XCTest
@testable import KTDatabasePlugin

final class RecentObjectStoreTests: XCTestCase {
    private let fm = FileManager.default

    private func makeStore(limit: Int = 20) -> (RecentObjectStore, URL) {
        let dir = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("kd-recent-\(UUID().uuidString)", isDirectory: true)
        try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
        let url = dir.appendingPathComponent("workspace-recent.json")
        return (RecentObjectStore(storeURL: url, limit: limit), url)
    }

    func testCapsAtLimitNewestFirst() {
        let (store, url) = makeStore(limit: 20)
        defer { try? fm.removeItem(at: url.deletingLastPathComponent()) }
        let pid = UUID()
        for index in 0..<25 {
            store.record(RecentObject(profileID: pid, database: "app", name: "t\(index)", isView: false))
        }
        XCTAssertEqual(store.recent().count, 20)
        XCTAssertEqual(store.recent().first?.name, "t24")
        XCTAssertEqual(store.recent().last?.name, "t5")
    }

    func testRecordDedupsAndMovesToFront() {
        let (store, url) = makeStore()
        defer { try? fm.removeItem(at: url.deletingLastPathComponent()) }
        let pid = UUID()
        store.record(RecentObject(profileID: pid, database: "app", name: "users", isView: false))
        store.record(RecentObject(profileID: pid, database: "app", name: "orders", isView: false))
        store.record(RecentObject(profileID: pid, database: "app", name: "users", isView: false))
        XCTAssertEqual(store.recent().count, 2)
        XCTAssertEqual(store.recent().first?.name, "users")
    }

    func testReloadsFromDisk() {
        let (store, url) = makeStore()
        defer { try? fm.removeItem(at: url.deletingLastPathComponent()) }
        let pid = UUID()
        store.record(RecentObject(profileID: pid, database: "app", name: "users", isView: false))
        let reloaded = RecentObjectStore(storeURL: url)
        XCTAssertEqual(reloaded.recent().map(\.name), ["users"])
    }
}
