import XCTest
@testable import KTStackKit

/// Log rotation is platform-owned (LogRotator stays in KTStackKit). Feature-owned Logs behavior
/// moved to KTLogsPlugin (KTLogsPluginTests).
final class LogRotatorTests: XCTestCase {
    func testRotationShiftsFilesAndTruncatesLive() throws {
        let dir = try tempDir(); defer { try? FileManager.default.removeItem(at: dir) }
        let log = dir.appendingPathComponent("nginx-error.log")
        try Data(repeating: 0x41, count: 2048).write(to: log) // 2KB
        let rotator = LogRotator(maxBytes: 1024, keep: 2)
        rotator.rotateIfNeeded(log)
        XCTAssertTrue(FileManager.default.fileExists(atPath: log.appendingPathExtension("1").path))
        let liveSize = try (FileManager.default.attributesOfItem(atPath: log.path)[.size] as? Int) ?? -1
        XCTAssertEqual(liveSize, 0, "live log truncated after rotation")
    }

    func testRotationSkipsUnderThreshold() throws {
        let dir = try tempDir(); defer { try? FileManager.default.removeItem(at: dir) }
        let log = dir.appendingPathComponent("small.log")
        try Data(repeating: 0x41, count: 100).write(to: log)
        LogRotator(maxBytes: 1024).rotateIfNeeded(log)
        XCTAssertFalse(FileManager.default.fileExists(atPath: log.appendingPathExtension("1").path))
    }

    private func tempDir() throws -> URL {
        let dir = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("kd-lm-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }
}
