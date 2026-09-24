import XCTest
@testable import KTStackKit

final class ServiceControlSemanticsTests: XCTestCase {
    private final class SlowFetch: @unchecked Sendable {
        let started = DispatchSemaphore(value: 0)
        let release = DispatchSemaphore(value: 0)
        func fetch() -> Set<String> {
            started.signal()
            release.wait()
            return []
        }
    }

    func testBootstrappedLabelIsVisibleImmediately() {
        let cache = LoadedLabelsCache(ttl: 60) { [] }
        XCTAssertFalse(cache.contains("com.ktstack.redis"))
        cache.markLoaded("com.ktstack.redis")
        XCTAssertTrue(cache.contains("com.ktstack.redis"))
        cache.markUnloaded("com.ktstack.redis")
        XCTAssertFalse(cache.contains("com.ktstack.redis"))
    }

    func testRefreshStartedBeforeBootstrapDoesNotHideTheNewLabel() {
        let slow = SlowFetch()
        let cache = LoadedLabelsCache(ttl: 0) { slow.fetch() }
        _ = cache.contains("com.ktstack.redis")
        XCTAssertEqual(slow.started.wait(timeout: .now() + 5), .success)

        cache.markLoaded("com.ktstack.redis")
        slow.release.signal()
        Thread.sleep(forTimeInterval: 0.2)

        XCTAssertTrue(cache.contains("com.ktstack.redis"), "a refresh that began before bootstrap must not drop the label")
        slow.release.signal()
    }

    func testRestartPolicyRemembersGivingUpUntilReset() {
        let policy = RestartPolicy(errorAfter: 0)
        XCTAssertTrue(policy.record(.redis, healthy: false).exhausted)
        policy.markGaveUp(.redis)
        XCTAssertTrue(policy.hasGivenUp(.redis))
        XCTAssertFalse(policy.isFailing(.redis))
        policy.reset(.redis)
        XCTAssertFalse(policy.hasGivenUp(.redis))
    }

    func testStrayReaperMatchesExecutableNotCommandLine() throws {
        let dir = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("ktstack-reaper-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        let mysqld = dir.appendingPathComponent("mysqld")
        try FileManager.default.copyItem(atPath: "/bin/sleep", toPath: mysqld.path)

        let lookalike = Process()
        lookalike.executableURL = URL(fileURLWithPath: "/bin/sh")
        lookalike.arguments = ["-c", "sleep 5", mysqld.path + "dump"]
        let real = Process()
        real.executableURL = mysqld
        real.arguments = ["5"]
        try lookalike.run()
        try real.run()
        defer { lookalike.terminate(); real.terminate() }
        Thread.sleep(forTimeInterval: 0.2)

        let pids = StrayProcessReaper.pids(matching: mysqld.path)
        XCTAssertTrue(pids.contains(real.processIdentifier))
        XCTAssertFalse(pids.contains(lookalike.processIdentifier))
    }
}
