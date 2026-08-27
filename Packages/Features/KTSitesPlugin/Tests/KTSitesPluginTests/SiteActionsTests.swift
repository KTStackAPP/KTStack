import XCTest
@testable import KTSitesPlugin

final class SiteActionsTests: XCTestCase {
    func testExportLineQuotesEnvValues() {
        let line = SiteActions.exportLine(port: 3000, env: ["APP_DEBUG": "1", "NAME": "it's"])
        XCTAssertEqual(line, "export PORT=3000 APP_DEBUG='1' NAME='it'\\''s'")
    }

    func testExportLineWithoutEnvIsJustPort() {
        XCTAssertEqual(SiteActions.exportLine(port: 5173, env: [:]), "export PORT=5173")
    }
}
