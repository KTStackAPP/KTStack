import KTStackCore
import XCTest
@testable import KTDatabasePlugin

@MainActor
final class WorkspaceSessionTests: XCTestCase {
    private func tempURL() -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    }

    private func makeSession() -> WorkspaceSession {
        let connections = ConnectionStore(storeURL: tempURL().appendingPathComponent("connections.json"))
        let shell = DatabaseV2ViewModel(tools: FakeDatabaseTools())
        let store = WorkspaceStore(
            connectionStore: connections,
            reachability: ServerReachabilityService(),
            recentStore: RecentObjectStore(storeURL: tempURL().appendingPathComponent("recent.json")),
            objectLoader: { [weak shell] _ in shell?.tables ?? [] },
            makeViewModel: { DatabaseV2ViewModel(tools: FakeDatabaseTools()) }
        )
        return WorkspaceSession(store: store, shell: shell, tools: FakeDatabaseTools(), paths: AppSupportPaths())
    }

    private var profileID: UUID { ConnectionProfile.managedMySQL.id }

    private func waitFor(_ predicate: @escaping () -> Bool, timeoutMs: Int = 1000) async {
        for _ in 0..<(timeoutMs / 5) where !predicate() {
            try? await Task.sleep(nanoseconds: 5_000_000)
        }
    }

    func testTabsAreIsolatedPerSession() {
        let a = makeSession()
        let b = makeSession()
        a.store.openTable(TableInfo(name: "t"), profileID: profileID, database: "db", forceNewTab: false)
        XCTAssertEqual(a.store.tabs.count, 1)
        XCTAssertTrue(b.store.tabs.isEmpty)
    }

    func testCloseAllClearsTabsAndDisconnectsShell() async {
        let session = makeSession()
        session.store.openTable(TableInfo(name: "t"), profileID: profileID, database: "db", forceNewTab: false)
        XCTAssertEqual(session.store.tabs.count, 1)

        await session.closeAll()
        XCTAssertTrue(session.store.tabs.isEmpty)
        XCTAssertNil(session.store.activeTabID)
        XCTAssertFalse(session.shell.connectionState.isConnectedState)
    }

    func testTitleReflectsSelectedProfile() async {
        let session = makeSession()
        XCTAssertEqual(session.title, "KTStack Database")

        session.store.selectedProfileID = profileID
        let expected = session.store.profiles.first { $0.id == profileID }?.name
        await waitFor { session.title == expected }
        XCTAssertEqual(session.title, expected)

        session.store.selectedProfileID = nil
        await waitFor { session.title == "KTStack Database" }
        XCTAssertEqual(session.title, "KTStack Database")
    }
    func testTitleReflectsSelectedDatabase() {
        let mySQL = ConnectionProfile.managedMySQL
        let profiles = [mySQL]

        let titleWithDB = WorkspaceSession.windowTitle(for: mySQL.id, in: profiles, database: "wordpress")
        XCTAssertEqual(titleWithDB, "\(mySQL.name) — wordpress")
        let hostOnlyProfile = ConnectionProfile(
            name: "127.0.0.1",
            kind: .mysql,
            host: "127.0.0.1",
            port: 3306,
            user: "root",
            database: "test"
        )
        let hostOnlyTitle = WorkspaceSession.windowTitle(for: hostOnlyProfile.id, in: [hostOnlyProfile], database: "test")
        XCTAssertEqual(hostOnlyTitle, "test")
    }

    func testSelectDatabaseSwitchesDatabaseAndUpdatesStore() async {
        let session = makeSession()
        session.store.selectedProfileID = profileID
        session.selectDatabase("wordpress")
        await waitFor { session.store.activeDatabase == "wordpress" }
        XCTAssertEqual(session.store.activeDatabase, "wordpress")
        XCTAssertEqual(session.shell.selectedDatabase, "wordpress")
    }
}

private extension DatabaseV2ViewModel.ConnectionState {
    var isConnectedState: Bool {
        if case .connected = self { return true }
        return false
    }
}
