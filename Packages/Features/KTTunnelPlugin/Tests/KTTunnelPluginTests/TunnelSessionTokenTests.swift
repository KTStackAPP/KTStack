import Foundation
import KTPlatformContracts
import KTStackCore
import XCTest
@testable import KTTunnelPlugin

private final class Gate: @unchecked Sendable {
    private let lock = NSLock()
    private var continuation: CheckedContinuation<Void, Never>?
    private var released = false

    func wait() async {
        await withCheckedContinuation { continuation in
            lock.lock()
            if released {
                lock.unlock()
                continuation.resume()
            } else {
                self.continuation = continuation
                lock.unlock()
            }
        }
    }

    func release() {
        lock.lock()
        released = true
        let pending = continuation
        continuation = nil
        lock.unlock()
        pending?.resume()
    }
}

private final class GatedOrigin: TunnelOriginConfiguring, @unchecked Sendable {
    let gate = Gate()
    private var calls = 0

    nonisolated var isFrontListening: Bool { true }

    @MainActor func prepareOrigin(siteID _: UUID) async throws -> Int {
        calls += 1
        guard calls == 1 else { return 45000 }
        await gate.wait()
        throw CocoaError(.fileReadUnknown)
    }

    @MainActor func applyPublicHost(_: String, siteID _: UUID, port _: Int, hostPrependFile _: URL) async {}
    nonisolated func removeOrigin(siteID _: UUID) {}
    nonisolated func removeAllOrigins(reloadFront _: Bool) {}
}

private struct IdleJobs: TunnelJobManaging {
    func bootstrapTunnelJob(label _: String, binary _: URL, arguments _: [String], logPath _: String) throws {}
    func bootoutTunnelJob(label _: String) {}
    func isTunnelJobLoaded(label _: String) -> Bool { true }
    func bootoutAllTunnelJobs() {}
}

private struct LocalBinaries: TunnelBinaryProviding {
    func ensureCloudflaredInstalled() async throws -> URL { URL(fileURLWithPath: "/tmp/cloudflared") }
}

@MainActor
final class TunnelSessionTokenTests: XCTestCase {
    func testAStaleStartCannotOverwriteTheNextSession() async throws {
        let root = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("kt-tun-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: root) }
        let origin = GatedOrigin()
        let manager = TunnelManager(origin: origin, jobs: IdleJobs(), binaries: LocalBinaries(), paths: AppSupportPaths(root: root))
        let target = TunnelSiteTarget(id: UUID(), domain: "app.test", secure: false)

        manager.start(target: target)
        try await Task.sleep(for: .milliseconds(50))
        manager.stop(site: target.id)
        manager.start(target: target)
        try await Task.sleep(for: .milliseconds(50))
        origin.gate.release()
        try await Task.sleep(for: .milliseconds(200))

        let status = try XCTUnwrap(manager.session(target.id)?.status)
        if case .error = status { XCTFail("the first start's failure leaked into the second session") }
        manager.stop(site: target.id)
    }

    func testURLParserSkipsTheAPIHost() {
        let log = "failed to reach https://api.trycloudflare.com/tunnel\nVisit it at https://calm-river-12.trycloudflare.com now"
        XCTAssertEqual(TrycloudflareURL.first(in: log)?.host, "calm-river-12.trycloudflare.com")
        XCTAssertNil(TrycloudflareURL.first(in: "error from https://api.trycloudflare.com"))
    }

    func testWatchdogWrapsTheCloudflaredCommand() {
        let launch = TunnelWatchdogLaunch(executable: URL(fileURLWithPath: "/App/kt"), deadline: nil)
        let wrapped = launch.wrap(binary: URL(fileURLWithPath: "/bin/cloudflared"), arguments: ["tunnel"], parentPID: 77)
        XCTAssertEqual(wrapped.binary.path, "/App/kt")
        XCTAssertEqual(wrapped.arguments, ["tunnel-watchdog", "--parent-pid", "77", "--", "/bin/cloudflared", "tunnel"])
    }
}
