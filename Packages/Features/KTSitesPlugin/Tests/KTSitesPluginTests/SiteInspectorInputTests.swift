import KTPlatformContracts
import XCTest
@testable import KTSitesPlugin

final class SiteInspectorInputTests: XCTestCase {
    func testDomainTrimsAndLowercases() {
        XCTAssertEqual(SiteInspectorInput.domain("  Shop.TEST "), "shop.test")
    }

    func testEmptyPortClearsRoute() {
        XCTAssertEqual(SiteInspectorInput.nodePort(""), .clear)
        XCTAssertEqual(SiteInspectorInput.nodePort("  \n"), .clear)
    }

    func testPortAcceptsFullRange() {
        XCTAssertEqual(SiteInspectorInput.nodePort("1"), .port(1))
        XCTAssertEqual(SiteInspectorInput.nodePort(" 3000\n"), .port(3000))
        XCTAssertEqual(SiteInspectorInput.nodePort("65535"), .port(65535))
    }

    func testPortRejectsOutOfRangeAndText() {
        for raw in ["0", "65536", "-1", "abc", "30 00"] {
            XCTAssertEqual(SiteInspectorInput.nodePort(raw), .invalid, raw)
        }
    }

    func testProxyDisplayFallsBackToRaw() {
        XCTAssertEqual(SiteInspectorInput.proxyDisplay(nil), "")
        XCTAssertEqual(SiteInspectorInput.proxyDisplay("::nope::"), "::nope::")
    }

    func testOpenNeedsServerForEveryKind() {
        for kind in [SiteKind.php, .staticSite, .node, .proxy] {
            XCTAssertFalse(SiteInspectorInput.canOpen(kind: kind, serverRunning: false, upstreamRunning: true), "\(kind)")
        }
    }

    func testOpenNeedsUpstreamForNodeAndProxy() {
        XCTAssertTrue(SiteInspectorInput.canOpen(kind: .php, serverRunning: true, upstreamRunning: false))
        XCTAssertTrue(SiteInspectorInput.canOpen(kind: .staticSite, serverRunning: true, upstreamRunning: false))
        XCTAssertFalse(SiteInspectorInput.canOpen(kind: .node, serverRunning: true, upstreamRunning: false))
        XCTAssertFalse(SiteInspectorInput.canOpen(kind: .proxy, serverRunning: true, upstreamRunning: false))
        XCTAssertTrue(SiteInspectorInput.canOpen(kind: .node, serverRunning: true, upstreamRunning: true))
    }
}
