import XCTest
@testable import KDWarmKit

final class TunnelModelsTests: XCTestCase {
    func testParsesURLFromCloudflaredBannerBox() {
        let banner = """
        2026-06-16T05:34:38Z INF +-----------------------------------------------+
        2026-06-16T05:34:38Z INF |  Your quick Tunnel has been created! Visit it  |
        2026-06-16T05:34:38Z INF |  https://settlement-outdoor-ruth-hill.trycloudflare.com   |
        2026-06-16T05:34:38Z INF +-----------------------------------------------+
        """
        XCTAssertEqual(TrycloudflareURL.first(in: banner)?.absoluteString,
                       "https://settlement-outdoor-ruth-hill.trycloudflare.com")
    }

    func testPartialBufferYieldsNilUntilURLComplete() {
        let partial = "2026 INF |  https://settlement-outdoor-ruth"
        XCTAssertNil(TrycloudflareURL.first(in: partial))
        let complete = partial + "-hill.trycloudflare.com  |"
        XCTAssertEqual(TrycloudflareURL.first(in: complete)?.host, "settlement-outdoor-ruth-hill.trycloudflare.com")
    }

    func testArgumentsUseDedicatedLoopbackOrigin() {
        let args = TunnelOrigin.cloudflaredArguments(port: 45123)
        XCTAssertEqual(args, ["tunnel", "--protocol", "http2", "--url", "http://127.0.0.1:45123", "--no-autoupdate"])
        XCTAssertFalse(args.contains("--no-tls-verify"))
    }

    func testArgumentsDoNotOverridePublicHostHeader() {
        let args = TunnelOrigin.cloudflaredArguments(port: 45123)
        XCTAssertFalse(args.contains("--http-host-header"))
        XCTAssertFalse(args.contains("secure.test"))
    }

    func testStatusPublicURLAndBusy() {
        let url = URL(string: "https://x.trycloudflare.com")!
        XCTAssertEqual(TunnelStatus.active(url).publicURL, url)
        XCTAssertNil(TunnelStatus.starting.publicURL)
        XCTAssertTrue(TunnelStatus.starting.isBusy)
        XCTAssertTrue(TunnelStatus.active(url).isBusy)
        XCTAssertFalse(TunnelStatus.idle.isBusy)
        XCTAssertFalse(TunnelStatus.error("x").isBusy)
    }

    func testProbeKeepsDNSFailuresPending() {
        XCTAssertEqual(TunnelController.probeDecision(statusCode: nil, locationHost: nil,
                                                      publicHost: "demo.trycloudflare.com",
                                                      localDomain: "app.test"),
                       .pending)
    }

    func testProbeRejectsRedirectBackToLocalDomain() {
        let decision = TunnelController.probeDecision(statusCode: 301,
                                                      locationHost: "app.test",
                                                      publicHost: "demo.trycloudflare.com",
                                                      localDomain: "app.test")
        guard case .failed(let message) = decision else {
            XCTFail("Expected failed redirect decision, got \(decision)")
            return
        }
        XCTAssertTrue(message.contains("redirects to local URL app.test"))
    }

    func testProbeAcceptsReachablePublicResponse() {
        XCTAssertEqual(TunnelController.probeDecision(statusCode: 200, locationHost: nil,
                                                      publicHost: "demo.trycloudflare.com",
                                                      localDomain: "app.test"),
                       .ready)
    }
}
