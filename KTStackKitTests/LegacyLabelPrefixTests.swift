import XCTest
@testable import KTStackKit

final class LegacyLabelPrefixTests: XCTestCase {
    private let fixture = """
    gui/501 = {
        services = {
            1234     0    com.ktstack.redis
            4321     0    com.kdwarm.mysql
            0        -    com.kdwarm.nginx
            99       -    com.apple.Finder
        }
    }
    """

    func testLegacyKDWarmLabelsAreFoundWithTheirOwnPrefix() {
        let legacy = LaunchAgentManager.parseLoadedLabels(from: fixture, prefix: "com.kdwarm.")
        XCTAssertEqual(legacy, ["com.kdwarm.mysql", "com.kdwarm.nginx"])
    }

    func testDefaultPrefixStillOnlyMatchesKTStackLabels() {
        XCTAssertEqual(LaunchAgentManager.parseLoadedLabels(from: fixture), ["com.ktstack.redis"])
    }
}
