import XCTest
@testable import KTStackKit

@MainActor
final class AppearancePreferenceTests: XCTestCase {
    func testAppearanceDefaultsToSystemAndPersists() throws {
        let suite = "ktstack-appearance-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }

        let prefs = AppPreferences(defaults: defaults)
        XCTAssertEqual(prefs.appearance, .system)
        prefs.appearance = .dark
        XCTAssertEqual(AppPreferences(defaults: defaults).appearance, .dark)
    }
}
