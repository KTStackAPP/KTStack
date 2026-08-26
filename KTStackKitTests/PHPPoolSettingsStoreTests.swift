import KTPlatformContracts
import KTStackCore
import XCTest
@testable import KTStackKit

final class PHPPoolSettingsStoreTests: XCTestCase {
    private func tempPaths() throws -> AppSupportPaths {
        let root = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("kd-pool-\(UUID().uuidString)", isDirectory: true)
        let paths = AppSupportPaths(root: root)
        try paths.ensureDirectoryTree()
        return paths
    }

    func testMissingFileReturnsDefault() throws {
        let paths = try tempPaths()
        defer { try? FileManager.default.removeItem(at: paths.root) }
        XCTAssertEqual(try PHPPoolSettingsStore(paths: paths).load(version: "8.4"), .default)
    }

    func testRoundTrip() throws {
        let paths = try tempPaths()
        defer { try? FileManager.default.removeItem(at: paths.root) }
        let store = PHPPoolSettingsStore(paths: paths)
        var settings = PHPPoolSettings.default
        settings.maxChildren = 20
        settings.processManager = .ondemand
        settings.processIdleTimeout = 30
        try store.write(version: "8.4", settings: settings)
        XCTAssertEqual(try store.load(version: "8.4"), settings)
    }

    func testWriteCreatesBackupOfPrevious() throws {
        let paths = try tempPaths()
        defer { try? FileManager.default.removeItem(at: paths.root) }
        let store = PHPPoolSettingsStore(paths: paths)
        var first = PHPPoolSettings.default
        first.maxChildren = 10
        try store.write(version: "8.4", settings: first)
        var second = first
        second.maxChildren = 25
        try store.write(version: "8.4", settings: second)

        let bak = paths.phpPoolSettings(version: "8.4").appendingPathExtension("bak")
        XCTAssertTrue(FileManager.default.fileExists(atPath: bak.path))
        let restored = try XCTUnwrap(try? PHPPoolSettingsStore(paths: paths).restoreBackup(version: "8.4"))
        XCTAssertTrue(restored)
        XCTAssertEqual(try store.load(version: "8.4"), first)
    }

    func testRestoreBackupReturnsFalseWithoutBackup() throws {
        let paths = try tempPaths()
        defer { try? FileManager.default.removeItem(at: paths.root) }
        XCTAssertFalse(try PHPPoolSettingsStore(paths: paths).restoreBackup(version: "8.4"))
    }

    func testCorruptFileThrows() throws {
        let paths = try tempPaths()
        defer { try? FileManager.default.removeItem(at: paths.root) }
        try FileManager.default.createDirectory(
            at: paths.phpIniDir(version: "8.4"), withIntermediateDirectories: true
        )
        try "{ not json".write(to: paths.phpPoolSettings(version: "8.4"), atomically: true, encoding: .utf8)
        XCTAssertThrowsError(try PHPPoolSettingsStore(paths: paths).load(version: "8.4"))
    }

    func testDecodeFillsMissingFieldsWithDefault() throws {
        let paths = try tempPaths()
        defer { try? FileManager.default.removeItem(at: paths.root) }
        try FileManager.default.createDirectory(
            at: paths.phpIniDir(version: "8.4"), withIntermediateDirectories: true
        )
        try #"{"maxChildren": 42}"#.write(
            to: paths.phpPoolSettings(version: "8.4"), atomically: true, encoding: .utf8
        )
        let loaded = try PHPPoolSettingsStore(paths: paths).load(version: "8.4")
        XCTAssertEqual(loaded.maxChildren, 42)
        XCTAssertEqual(loaded.processManager, .dynamic)
        XCTAssertEqual(loaded.maxRequests, PHPPoolSettings.default.maxRequests)
    }

    func testValidateDynamicOrdering() {
        var s = PHPPoolSettings.default
        XCTAssertNil(s.validate())
        s.startServers = 9 // > maxSpareServers(3)
        XCTAssertNotNil(s.validate())
        s = .default
        s.minSpareServers = 0
        XCTAssertNotNil(s.validate())
        s = .default
        s.maxSpareServers = 99 // > maxChildren(5)
        XCTAssertNotNil(s.validate())
    }

    func testValidateOndemandIdleTimeout() {
        var s = PHPPoolSettings.default
        s.processManager = .ondemand
        s.processIdleTimeout = 0
        XCTAssertNotNil(s.validate())
        s.processIdleTimeout = 10
        XCTAssertNil(s.validate())
    }

    func testValidateMaxChildrenFloor() {
        var s = PHPPoolSettings.default
        s.maxChildren = 0
        XCTAssertNotNil(s.validate())
    }

    func testValidateStaticIgnoresSpareOrdering() {
        var s = PHPPoolSettings.default
        s.processManager = .static
        s.startServers = 99 // irrelevant for static
        XCTAssertNil(s.validate())
    }
}
