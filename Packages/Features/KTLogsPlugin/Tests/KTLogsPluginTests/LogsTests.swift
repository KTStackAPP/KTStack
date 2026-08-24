import KTStackCore
import XCTest
@testable import KTLogsPlugin

/// Feature tests for the Logs plugin: severity parsing + ring buffer, source catalog, and
/// incremental tail. Log rotation is platform-owned and tested in KTStackKit (LogRotatorTests).
final class LogsTests: XCTestCase {
    func testSeverityClassification() {
        XCTAssertEqual(LogLineStore.severity(of: "2026/06/11 [error] connect() failed"), .error)
        XCTAssertEqual(LogLineStore.severity(of: "[warn] low on workers"), .warning)
        XCTAssertEqual(LogLineStore.severity(of: "PHP Warning: undefined var"), .warning)
        XCTAssertEqual(LogLineStore.severity(of: "GET / 200 OK"), .info)
    }

    func testRingBufferEvictsOldestPastCapacity() {
        let store = LogLineStore(capacity: 3)
        store.append(["a", "b", "c", "d", "e"])
        let lines = store.snapshot()
        XCTAssertEqual(lines.map(\.text), ["c", "d", "e"])
        XCTAssertEqual(lines.map(\.id), [2, 3, 4]) // ids monotonic; the 2 oldest evicted
    }

    func testFilterIsCaseInsensitiveSubstring() {
        let store = LogLineStore()
        store.append(["GET /index.php", "POST /api", "error: boom"])
        XCTAssertEqual(store.filtered("api").map(\.text), ["POST /api"])
        XCTAssertEqual(store.filtered("ERROR").map(\.text), ["error: boom"])
        XCTAssertEqual(store.filtered("").count, 3)
    }

    func testCatalogListsCoreAndExistingSources() throws {
        let root = try tempDir(); defer { try? FileManager.default.removeItem(at: root) }
        let paths = AppSupportPaths(root: root)
        try paths.ensureDirectoryTree()
        try Data().write(to: paths.serviceLog("redis")) // redis ran
        try Data().write(to: paths.siteAccessLog("demo.test")) // a site served
        let sources = LogCatalog(paths: paths).sources(siteDomains: ["demo.test"], phpVersions: ["8.4"])
        let ids = Set(sources.map(\.id))
        XCTAssertTrue(ids.contains("nginx-error")) // core, always listed
        XCTAssertTrue(ids.contains("php-8.4")) // active pool
        XCTAssertTrue(ids.contains("redis")) // exists
        XCTAssertTrue(ids.contains("site-demo.test-access")) // exists
        XCTAssertFalse(ids.contains("mysql")) // never ran → absent
    }

    /// Deterministic backfill coverage: on open, the reader emits the file's existing lines. The
    /// live-append path is driven by OS file-system events (flaky to unit-test) and is covered by
    /// real app usage instead.
    func testTailReaderBackfillsExistingLines() throws {
        let dir = try tempDir(); defer { try? FileManager.default.removeItem(at: dir) }
        let log = dir.appendingPathComponent("t.log")
        try "line1\nline2\n".write(to: log, atomically: true, encoding: .utf8)

        let gotBackfill = expectation(description: "backfill")
        let lock = NSLock()
        var collected: [String] = []
        var fulfilled = false
        let reader = LogTailReader(url: log)
        reader.onLines = { batch in
            lock.lock()
            collected.append(contentsOf: batch)
            let done = collected.contains("line1") && collected.contains("line2") && !fulfilled
            if done { fulfilled = true }
            lock.unlock()
            if done { gotBackfill.fulfill() }
        }
        reader.start()
        wait(for: [gotBackfill], timeout: 3)
        reader.stop()
    }

    private func tempDir() throws -> URL {
        let dir = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("kd-lm-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }
}
