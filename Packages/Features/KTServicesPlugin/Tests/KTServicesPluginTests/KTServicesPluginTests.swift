import KTPlatformContracts
import XCTest
@testable import KTServicesPlugin

@MainActor
final class KTServicesPluginTests: XCTestCase {
    private func makePlugin(services: FakeServiceManaging = FakeServiceManaging(states: [makeState(.nginx)])) -> KTServicesPlugin {
        KTServicesPlugin(
            services: services,
            engines: FakeEngineVersionManaging(),
            dns: FakeDNSResolver(),
            caTrust: FakeCATrust(),
            nginxInclude: FakeNginxInclude(),
            route: { _ in }
        )
    }

    func testDescriptor() {
        let plugin = makePlugin()
        XCTAssertEqual(plugin.descriptor.id, "services")
        XCTAssertEqual(plugin.descriptor.title, "Services")
        XCTAssertEqual(plugin.descriptor.systemImage, "server.rack")
    }

    func testLiveUpdatesFollowSectionActivation() {
        let services = FakeServiceManaging(states: [makeState(.nginx)])
        let plugin = makePlugin(services: services)
        XCTAssertEqual(services.liveUpdateClients, 0)
        plugin.sectionDidActivate()
        XCTAssertEqual(services.liveUpdateClients, 1)
        plugin.sectionDidDeactivate()
        XCTAssertEqual(services.liveUpdateClients, 0)
    }

    func testMakeContentViewDoesNotCrash() {
        let plugin = makePlugin()
        _ = plugin.makeContentView()
    }
}
