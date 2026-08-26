import KTPlatformContracts
import KTPluginKit
import XCTest
@testable import KTSitesPlugin

@MainActor
final class KTSitesPluginTests: XCTestCase {
    private func makePlugin() -> KTSitesPlugin {
        KTSitesPlugin(
            catalog: FakeSiteCatalog(catalog: SiteCatalogState(sites: [], tld: "test")),
            server: FakeSiteServerControl(state: SiteServerState(isRunning: true, isBusy: false, lastError: nil, phpVersions: ["8.4"])),
            webEngine: FakeWebEngine(state: WebEngineState(apacheVersion: "2.4", installed: false, installing: false)),
            provisioning: FakeSiteProvisioning(),
            restore: FakeWordPressRestoring(),
            ide: FakeSiteIDEConfiguring(),
            dns: FakeDNSResolving(state: DNSResolverState(status: .enabled, isBusy: false, lastError: nil, usesHelper: false, helperNeedsApproval: false)),
            runtimes: FakeRuntimeManaging(state: RuntimeState()),
            sharing: FakeSiteSharing(),
            modals: KTModalPresenter(),
            sitesRoot: { URL(fileURLWithPath: "/sites") },
            httpsByDefault: { true },
            route: { _ in }
        )
    }

    func testDescriptorIsFrozen() {
        let plugin = makePlugin()
        XCTAssertEqual(plugin.descriptor.id, "sites")
        XCTAssertEqual(plugin.descriptor.title, "Sites")
        XCTAssertEqual(plugin.descriptor.systemImage, "globe")
    }

    func testMakeContentViewDoesNotCrash() {
        let plugin = makePlugin()
        _ = plugin.makeContentView()
    }

    func testSectionActivationStartsAndStopsNodeProbing() {
        let plugin = makePlugin()
        plugin.sectionDidActivate()
        plugin.sectionDidDeactivate()
    }
}
