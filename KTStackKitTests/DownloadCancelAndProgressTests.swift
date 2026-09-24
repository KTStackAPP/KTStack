import XCTest
@testable import KTStackKit

final class DownloadCancelAndProgressTests: XCTestCase {
    private final class Clock: @unchecked Sendable {
        private let lock = NSLock()
        private var current = Date(timeIntervalSince1970: 1000)
        var now: Date { lock.lock(); defer { lock.unlock() }; return current }
        func advance(_ seconds: TimeInterval) { lock.lock(); current += seconds; lock.unlock() }
    }

    func testProgressIsThrottledButFinalUpdateAlwaysReported() {
        let clock = Clock()
        let coordinator = DownloadCoordinator(now: { clock.now }) { _, _ in }
        XCTAssertTrue(coordinator.shouldReport(written: 10, expected: 100))
        clock.advance(0.05)
        XCTAssertFalse(coordinator.shouldReport(written: 20, expected: 100))
        clock.advance(0.06)
        XCTAssertTrue(coordinator.shouldReport(written: 30, expected: 100))
        clock.advance(0.01)
        XCTAssertTrue(coordinator.shouldReport(written: 100, expected: 100))
    }

    func testCancelBeforeTheTaskStartsStillCancelsTheDownload() async {
        let coordinator = DownloadCoordinator { _, _ in }
        coordinator.cancel()
        let started = Date()
        do {
            _ = try await coordinator.download(URL(string: "https://10.255.255.1/runtime.tar.gz")!)
            XCTFail("a cancelled download must not succeed")
        } catch {
            XCTAssertTrue(error is CancellationError, "got \(error)")
        }
        XCTAssertLessThan(Date().timeIntervalSince(started), 10)
    }

    func testFailedExtractRemovesItsWorkDirectory() throws {
        let root = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("kd-extract-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let bogus = root.appendingPathComponent("broken.tar.gz")
        try Data("not an archive".utf8).write(to: bogus)

        XCTAssertThrowsError(try RuntimeDownloader.extract(bogus, into: root))

        let leftovers = try FileManager.default.contentsOfDirectory(atPath: root.path).filter { $0.hasPrefix(".dl-") }
        XCTAssertEqual(leftovers, [])
    }

    func testExtractReturnsSingleTopLevelDirectory() throws {
        let root = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("kd-extract-ok-\(UUID().uuidString)")
        let source = root.appendingPathComponent("src/pkg-1.0")
        try FileManager.default.createDirectory(at: source, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        try Data("hi".utf8).write(to: source.appendingPathComponent("README"))
        let archive = root.appendingPathComponent("pkg.tar.gz")
        let tar = Process()
        tar.executableURL = URL(fileURLWithPath: "/usr/bin/tar")
        tar.arguments = ["-czf", archive.path, "-C", root.appendingPathComponent("src").path, "pkg-1.0"]
        try tar.run()
        tar.waitUntilExit()

        let payload = try RuntimeDownloader.extract(archive, into: root)

        XCTAssertEqual(payload.lastPathComponent, "pkg-1.0")
        XCTAssertTrue(FileManager.default.fileExists(atPath: payload.appendingPathComponent("README").path))
    }
}
