import KTPlatformContracts
import XCTest
@testable import KTServicesPlugin

@MainActor
final class KTServicesPluginTests: XCTestCase {
    private func makePlugin() -> KTServicesPlugin {
        KTServicesPlugin(
            services: FakeServiceManaging(states: [makeState(.nginx)]),
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

    func testMakeContentViewDoesNotCrash() {
        let plugin = makePlugin()
        _ = plugin.makeContentView()
    }
}
