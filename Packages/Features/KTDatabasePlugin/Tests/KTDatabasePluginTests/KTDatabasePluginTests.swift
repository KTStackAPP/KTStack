import KTPlatformContracts
import KTPluginKit
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

    private final class FakeSites: SiteCatalogManaging {
        var catalog = SiteCatalogState(sites: [], tld: "test")
        func catalogStream() -> AsyncStream<SiteCatalogState> { AsyncStream { $0.finish() } }
        func setPHPVersion(_: UUID, _: String) {}
        func editDomain(_: UUID, _: String) throws {}
        func validateDomain(_: String, excluding _: UUID?) throws {}
        func setSecure(_: UUID, _: Bool) {}
        func setNodePort(_: UUID, _: Int?) {}
        func setEngine(_: UUID, _: SiteServerEngine) {}
        func setProxyTarget(_: UUID, _: String) throws {}
        func setAliases(_: UUID, _: [String]) throws {}
        func validateAliases(_: [String], for _: UUID) throws {}
        func setEnvVars(_: UUID, _: [String: String]) throws {}
        func saveFrontDirectives(_: UUID, _: String) async throws {}
    }

    private func makePlugin(route: @escaping @MainActor (DatabaseRoute) -> Void) -> KTDatabasePlugin {
        KTDatabasePlugin(
            tools: FakeDatabaseTools(),
            engines: FakeEngines(),
            sites: FakeSites(),
            modals: KTModalPresenter(),
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
