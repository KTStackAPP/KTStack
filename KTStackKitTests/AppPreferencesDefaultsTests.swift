import XCTest
@testable import KTStackKit

@MainActor
final class AppPreferencesDefaultsTests: XCTestCase {
    private func freshDefaults() -> UserDefaults {
        let suite = "ktstack-prefs-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        return defaults
    }

    func testTogglesDefaultToExpectedValues() {
        let prefs = AppPreferences(defaults: freshDefaults())
        XCTAssertTrue(prefs.showInMenuBar)
        XCTAssertFalse(prefs.monochromeMenuBarIcon)
        XCTAssertTrue(prefs.serveHTTPSByDefault)
        XCTAssertTrue(prefs.automaticUpdates)
        XCTAssertFalse(prefs.launchAtLogin)
        XCTAssertFalse(prefs.autoStartServer)
        XCTAssertEqual(prefs.releaseChannel, .stable)
    }

    func testReleaseChannelFallsBackToStableOnGarbage() {
        let defaults = freshDefaults()
        defaults.set("nonsense", forKey: "KTStack.releaseChannel")
        let prefs = AppPreferences(defaults: defaults)
        XCTAssertEqual(prefs.releaseChannel, .stable)
    }

    func testMutatingTogglePersistsToDefaults() {
        let defaults = freshDefaults()
        let prefs = AppPreferences(defaults: defaults)
        prefs.autoStartServer = true
        prefs.monochromeMenuBarIcon = true
        prefs.releaseChannel = .beta
        XCTAssertTrue(defaults.bool(forKey: "KTStack.autoStartServer"))
        XCTAssertTrue(defaults.bool(forKey: "KTStack.monochromeMenuBarIcon"))
        XCTAssertEqual(defaults.string(forKey: "KTStack.releaseChannel"), "beta")

        let reloaded = AppPreferences(defaults: defaults)
        XCTAssertTrue(reloaded.autoStartServer)
        XCTAssertTrue(reloaded.monochromeMenuBarIcon)
        XCTAssertEqual(reloaded.releaseChannel, .beta)
    }
}
