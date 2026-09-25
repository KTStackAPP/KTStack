import XCTest
@testable import KTStackKit

final class ServerActionQueuePolicyTests: XCTestCase {
    func testQueueingDefaultsToOnAndHonoursOptOut() throws {
        let defaults = try XCTUnwrap(UserDefaults(suiteName: "kt-queue-\(UUID().uuidString)"))
        XCTAssertTrue(ServerActionQueuePolicy.isEnabled(defaults: defaults))
        defaults.set(false, forKey: ServerActionQueuePolicy.defaultsKey)
        XCTAssertFalse(ServerActionQueuePolicy.isEnabled(defaults: defaults))
    }

    @MainActor
    func testPreferenceWritesThePolicyKey() throws {
        let defaults = try XCTUnwrap(UserDefaults(suiteName: "kt-queue-\(UUID().uuidString)"))
        let preferences = AppPreferences(defaults: defaults)
        XCTAssertTrue(preferences.queueServerActions)
        preferences.queueServerActions = false
        XCTAssertFalse(ServerActionQueuePolicy.isEnabled(defaults: defaults))
    }
}
