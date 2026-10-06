@testable import KTSitesPlugin
import XCTest

final class SiteDetailSummaryTests: XCTestCase {
    func testEnvironmentCountsVariables() {
        XCTAssertEqual(SiteDetailSummary.environment([:]), "None")
        XCTAssertEqual(SiteDetailSummary.environment(["APP_ENV": "local"]), "1 variable")
        XCTAssertEqual(SiteDetailSummary.environment(["A": "1", "B": "2", "C": "3"]), "3 variables")
    }

    func testDirectivesCountNonEmptyLines() {
        XCTAssertEqual(SiteDetailSummary.directives(nil), "None")
        XCTAssertEqual(SiteDetailSummary.directives("  \n\n "), "None")
        XCTAssertEqual(SiteDetailSummary.directives("client_max_body_size 64m;"), "1 line")
        XCTAssertEqual(SiteDetailSummary.directives("a 1;\n\nb 2;\n"), "2 lines")
    }

    func testWorkersFallBackToNone() {
        XCTAssertEqual(SiteDetailSummary.workers(SiteWorkersSummary(total: 0, active: 0, failing: 0)), "None")
        XCTAssertEqual(SiteDetailSummary.workers(SiteWorkersSummary(total: 2, active: 1, failing: 0)), "1/2 workers")
        XCTAssertEqual(SiteDetailSummary.workers(SiteWorkersSummary(total: 2, active: 1, failing: 1)), "1 worker failing")
    }
}
