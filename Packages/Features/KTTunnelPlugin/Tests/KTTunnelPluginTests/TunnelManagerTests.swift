import Foundation
import KTPlatformContracts
import KTStackCore
import XCTest
@testable import KTTunnelPlugin

private final class FakeOrigin: TunnelOriginConfiguring, @unchecked Sendable {
    private let front: Bool
    init(front: Bool = false) { self.front = front }
    nonisolated var isFrontListening: Bool { front }
    @MainActor func prepareOrigin(siteID _: UUID) async throws -> Int { 45000 }
    @MainActor func applyPublicHost(_: String, siteID _: UUID, port _: Int, hostPrependFile _: URL) async {}
    nonisolated func removeOrigin(siteID _: UUID) {}
    nonisolated func removeAllOrigins(reloadFront _: Bool) {}
}

private struct FakeJobs: TunnelJobManaging {
    func bootstrapTunnelJob(label _: String, binary _: URL, arguments _: [String], logPath _: String) throws {}
    func bootoutTunnelJob(label _: String) {}
    func isTunnelJobLoaded(label _: String) -> Bool { false }
    func bootoutAllTunnelJobs() {}
}

private struct FakeBinaries: TunnelBinaryProviding {
    func ensureCloudflaredInstalled() async throws -> URL { URL(fileURLWithPath: "/tmp/cloudflared") }
}

@MainActor
final class TunnelManagerTests: XCTestCase {
    private func tempManager() -> (TunnelManager, URL) {
        let root = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("ktstack-tunnel-mgr-\(UUID().uuidString)")
        let mgr = TunnelManager(
            origin: FakeOrigin(),
            jobs: FakeJobs(),
            binaries: FakeBinaries(),
            paths: AppSupportPaths(root: root)
        )
        return (mgr, root)
    }

    private func target(_ domain: String, id: UUID = UUID(), secure: Bool = false) -> TunnelSiteTarget {
        TunnelSiteTarget(id: id, domain: domain, secure: secure)
    }

    func testInFlightGuardAllowsOneSessionPerSite() {
        let (mgr, root) = tempManager()
        defer { try? FileManager.default.removeItem(at: root) }
        let t = target("demo.test")
        mgr.start(target: t)
        mgr.start(target: t)
        XCTAssertEqual(mgr.sessions.count, 1)
        XCTAssertTrue(mgr.isSharing(t.id))
        if case .starting = mgr.session(t.id)!.status {} else { XCTFail("expected .starting") }
        mgr.stop(site: t.id)
        XCTAssertFalse(mgr.isSharing(t.id))
    }

    func testReconcileStopsRenamedAndRemovedSites() {
        let (mgr, root) = tempManager()
        defer { try? FileManager.default.removeItem(at: root) }
        let a = target("a.test"), b = target("b.test")
        mgr.start(target: a)
        mgr.start(target: b)
        XCTAssertEqual(mgr.sessions.count, 2)

        let renamedA = target("a2.test", id: a.id)
        mgr.reconcile(targets: [renamedA])
        XCTAssertNil(mgr.session(a.id), "domain changed → tunnel stopped")
        XCTAssertNil(mgr.session(b.id), "site removed → tunnel stopped")
    }

    func testReconcileKeepsUnchangedSite() {
        let (mgr, root) = tempManager()
        defer { try? FileManager.default.removeItem(at: root) }
        let a = target("keep.test")
        mgr.start(target: a)
        mgr.reconcile(targets: [a])
        XCTAssertTrue(mgr.isSharing(a.id))
        mgr.stop(site: a.id)
    }

    func testReconcileStopsSecureFlippedSite() {
        let (mgr, root) = tempManager()
        defer { try? FileManager.default.removeItem(at: root) }
        let plain = target("flip.test")
        mgr.start(target: plain)
        let flipped = target("flip.test", id: plain.id, secure: true)
        mgr.reconcile(targets: [flipped])
        XCTAssertNil(mgr.session(plain.id), "secure-flip changes origin port → tunnel stopped")
    }

    func testReShareAfterStopCreatesFreshSession() {
        let (mgr, root) = tempManager()
        defer { try? FileManager.default.removeItem(at: root) }
        let a = target("again.test")
        mgr.start(target: a)
        mgr.stop(site: a.id)
        XCTAssertFalse(mgr.isSharing(a.id))
        mgr.start(target: a)
        XCTAssertEqual(mgr.sessions.count, 1)
        XCTAssertTrue(mgr.isSharing(a.id))
        mgr.stop(site: a.id)
    }
}
