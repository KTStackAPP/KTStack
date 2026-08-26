import Foundation
import KTPlatformContracts
import KTStackCore
import XCTest
@testable import KTTunnelPlugin

final class TunnelManagerSharingTests: XCTestCase {
    private func session(_ status: TunnelStatus, expiresAt: Date? = nil) -> TunnelSession {
        TunnelSession(siteID: UUID(), domain: "app.test", secure: true, status: status, expiresAt: expiresAt)
    }

    func testStartingMapsToStartingState() {
        let s = TunnelManager.shareState(session(.starting))
        XCTAssertEqual(s?.starting, true)
        XCTAssertNil(s?.publicURL)
        XCTAssertNil(s?.error)
    }

    func testActiveMapsToPublicURL() throws {
        let url = URL(string: "https://x.trycloudflare.com")!
        let s = TunnelManager.shareState(session(.active(url)))
        XCTAssertEqual(s?.starting, false)
        XCTAssertEqual(s?.publicURL, url)
    }

    func testActiveUnverifiedMapsToPublicURL() throws {
        let url = URL(string: "https://y.trycloudflare.com")!
        let s = TunnelManager.shareState(session(.activeUnverified(url)))
        XCTAssertEqual(s?.publicURL, url)
    }

    func testErrorMapsToErrorMessage() {
        let s = TunnelManager.shareState(session(.error("boom")))
        XCTAssertEqual(s?.error, "boom")
        XCTAssertNil(s?.publicURL)
    }

    func testIdleAndExpiredMapToNil() {
        XCTAssertNil(TunnelManager.shareState(session(.idle)))
        XCTAssertNil(TunnelManager.shareState(session(.expired)))
    }

    @MainActor
    func testShareStateStreamFirstValueEqualsCurrent() async {
        let manager = TunnelManager(
            origin: NoopOrigin(), jobs: NoopJobs(), binaries: NoopBinaries()
        )
        var iterator = manager.shareStateStream().makeAsyncIterator()
        let first = await iterator.next()
        XCTAssertEqual(first, manager.shareStates)
        XCTAssertTrue(first?.isEmpty ?? false)
    }
}

private final class NoopOrigin: TunnelOriginConfiguring {
    var isFrontListening: Bool { false }
    func prepareOrigin(siteID _: UUID) async throws -> Int { 0 }
    func applyPublicHost(_: String, siteID _: UUID, port _: Int, hostPrependFile _: URL) async {}
    func removeOrigin(siteID _: UUID) {}
    func removeAllOrigins(reloadFront _: Bool) {}
}

private struct NoopJobs: TunnelJobManaging {
    func bootstrapTunnelJob(label _: String, binary _: URL, arguments _: [String], logPath _: String) throws {}
    func bootoutTunnelJob(label _: String) {}
    func isTunnelJobLoaded(label _: String) -> Bool { false }
    func bootoutAllTunnelJobs() {}
}

private struct NoopBinaries: TunnelBinaryProviding {
    func ensureCloudflaredInstalled() async throws -> URL { URL(fileURLWithPath: "/dev/null") }
}
