import KTPlatformContracts
import XCTest
@testable import KTRuntimesPlugin

@MainActor
final class KTRuntimesPluginTests: XCTestCase {
    private func makePlugin() -> KTRuntimesPlugin {
        KTRuntimesPlugin(
            runtimes: FakeRuntimeManaging(),
            webEngine: FakeWebEngine(),
            phpSites: FakePHPSites(),
            phpConfig: FakePHPConfig(),
            engines: FakeEngines()
        )
    }

    func testDescriptor() {
        let descriptor = makePlugin().descriptor
        XCTAssertEqual(descriptor.id, "runtimes")
        XCTAssertEqual(descriptor.title, "Runtimes")
        XCTAssertEqual(descriptor.systemImage, "cube")
    }

    func testMakeContentViewDoesNotCrash() {
        _ = makePlugin().makeContentView()
    }

    func testXdebugModelReadsInitialState() {
        let config = FakePHPConfig()
        config.clientPort = 9004
        config.supported = ["8.3": true]
        config.enabledFlags = ["8.3": true]
        let model = XdebugToggleModel(version: "8.3", phpConfig: config)
        XCTAssertEqual(model.clientPort, 9004)
        XCTAssertTrue(model.supported)
        XCTAssertTrue(model.enabled)
    }

    func testXdebugToggleForwardsAndUpdates() async {
        let config = FakePHPConfig()
        config.supported = ["8.3": true]
        config.enabledFlags = ["8.3": false]
        let model = XdebugToggleModel(version: "8.3", phpConfig: config)
        model.toggle(true)
        for _ in 0 ..< 50 where model.busy { await Task.yield() }
        XCTAssertEqual(config.setXdebugCalls.first?.0, true)
        XCTAssertTrue(model.enabled)
    }

    func testXdebugToggleIgnoredWhenUnsupported() {
        let config = FakePHPConfig()
        config.supported = ["8.3": false]
        let model = XdebugToggleModel(version: "8.3", phpConfig: config)
        model.toggle(true)
        XCTAssertTrue(config.setXdebugCalls.isEmpty)
    }
}
