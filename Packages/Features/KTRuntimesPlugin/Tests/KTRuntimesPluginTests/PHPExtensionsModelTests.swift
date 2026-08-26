import KTPlatformContracts
import XCTest
@testable import KTRuntimesPlugin

@MainActor
final class PHPExtensionsModelTests: XCTestCase {
    private func entry(_ id: String, _ state: PHPExtensionState) -> PHPExtensionEntry {
        PHPExtensionEntry(
            ext: PHPExtensionInfo(id: id, displayName: id, kind: "optional", summary: "", isBuiltIn: false),
            state: state
        )
    }

    func testRefreshPopulatesRows() async {
        let config = FakePHPConfig()
        config.entries = [entry("redis", .available), entry("xdebug", .installed)]
        let model = PHPExtensionsModel(version: "8.3", phpConfig: config)
        await model.refresh()
        XCTAssertEqual(model.rows.map(\.ext.id), ["redis", "xdebug"])
    }

    func testInstallSuccessForwardsAndClears() async {
        let config = FakePHPConfig()
        let model = PHPExtensionsModel(version: "8.3", phpConfig: config)
        await model.install("redis")
        XCTAssertEqual(config.installCalls, ["redis"])
        XCTAssertNil(model.errors["redis"])
        XCTAssertFalse(model.busy.contains("redis"))
    }

    func testInstallFailedToLoadSurfacesWarning() async {
        let config = FakePHPConfig()
        config.installOutcome = PHPExtensionInstallOutcome(loaded: false, warning: "missing dep")
        let model = PHPExtensionsModel(version: "8.3", phpConfig: config)
        await model.install("imagick")
        XCTAssertEqual(model.errors["imagick"], "missing dep")
    }

    func testInstallErrorSurfacesDescription() async {
        let config = FakePHPConfig()
        config.installError = TestError.boom
        let model = PHPExtensionsModel(version: "8.3", phpConfig: config)
        await model.install("swoole")
        XCTAssertNotNil(model.errors["swoole"])
    }

    func testUninstallForwards() async {
        let config = FakePHPConfig()
        let model = PHPExtensionsModel(version: "8.3", phpConfig: config)
        await model.uninstall("redis")
        XCTAssertEqual(config.uninstallCalls, ["redis"])
    }
}

private enum TestError: Error { case boom }
