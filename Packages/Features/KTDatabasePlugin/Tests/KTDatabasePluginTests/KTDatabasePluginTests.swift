import KTPlatformContracts
import KTStackCore
import XCTest
@testable import KTDatabasePlugin

@MainActor
final class KTDatabasePluginTests: XCTestCase {
    private final class FakeEngines: DatabaseEngineManaging {
        func isRunning(_: DatabaseEngine) -> Bool { false }
        func install(_: DatabaseEngine) {}
        func toggle(_: DatabaseEngine) {}
    }

    private func makePlugin(route: @escaping @MainActor (DatabaseRoute) -> Void) -> KTDatabasePlugin {
        KTDatabasePlugin(
            tools: FakeDatabaseTools(),
            engines: FakeEngines(),
            paths: AppSupportPaths(),
            route: route
        )
    }

    func testDescriptorIdentity() {
        let plugin = makePlugin(route: { _ in })
        XCTAssertEqual(plugin.descriptor.id, "database")
        XCTAssertEqual(plugin.descriptor.title, "Database")
    }

    func testOpenDatabasePanelRoutesToWorkspace() {
        var routed: [DatabaseRoute] = []
        let plugin = makePlugin(route: { routed.append($0) })
        plugin.openDatabasePanel()
        XCTAssertEqual(routed.first, .workspace(profileID: nil))
    }

    func testOpenWorkspaceCarriesProfileID() {
        var routed: [DatabaseRoute] = []
        let plugin = makePlugin(route: { routed.append($0) })
        let profile = ConnectionProfile(name: "t", kind: .mysql, host: "127.0.0.1", port: 3306, user: "root", database: "db")
        plugin.openWorkspace(profile)
        XCTAssertEqual(routed.first, .workspace(profileID: profile.id))
    }

    func testCloseDocumentBrowserEmitsCloseEvent() {
        var routed: [DatabaseRoute] = []
        let plugin = makePlugin(route: { routed.append($0) })
        plugin.closeDocumentBrowser()
        XCTAssertEqual(routed, [.closeDocumentBrowser])
    }
}
