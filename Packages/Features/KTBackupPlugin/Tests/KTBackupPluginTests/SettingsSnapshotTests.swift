import Foundation
import XCTest
@testable import KTBackupPlugin

final class SettingsSnapshotTests: XCTestCase {
    func testSnapshotCopiesConfigButNeverCertificatesOrSecrets() throws {
        let support = try makeTemporaryDirectory()
        let fileManager = FileManager.default
        for directory in ["config/sites", "config/php/8.3", "config/ca", "config/certs/shop.test"] {
            try fileManager.createDirectory(at: support.appendingPathComponent(directory), withIntermediateDirectories: true)
        }
        try Data("[]".utf8).write(to: support.appendingPathComponent("config/sites/sites.json"))
        try Data("memory_limit=1G".utf8).write(to: support.appendingPathComponent("config/php/8.3/php.ini"))
        try Data("KEY".utf8).write(to: support.appendingPathComponent("config/ca/rootCA-key.pem"))
        try Data("KEY".utf8).write(to: support.appendingPathComponent("config/certs/shop.test/key.pem"))
        let domain = "ktstack.tests.\(UUID().uuidString)"
        UserDefaults.standard.setPersistentDomain(
            ["KTStack.tld": "test", "KTStack.apiToken": "abc", "db_password": "pw", "KTStack.devMode": true], forName: domain
        )
        defer { UserDefaults.standard.removePersistentDomain(forName: domain) }
        let output = try makeTemporaryDirectory().appendingPathComponent("settings", isDirectory: true)
        let now = date("2026-05-10 02:00:00")
        try SettingsSnapshotWriter(appSupportRoot: support, defaultsDomain: domain, now: { now }).write(into: output)

        XCTAssertTrue(fileManager.fileExists(atPath: output.appendingPathComponent("config/php/8.3/php.ini").path))
        XCTAssertFalse(fileManager.fileExists(atPath: output.appendingPathComponent("config/ca").path))
        XCTAssertFalse(fileManager.fileExists(atPath: output.appendingPathComponent("config/certs").path))
        let plist = try Data(contentsOf: output.appendingPathComponent("preferences.plist"))
        let preferences = try XCTUnwrap(PropertyListSerialization.propertyList(from: plist, format: nil) as? [String: Any])
        XCTAssertEqual(Set(preferences.keys), ["KTStack.tld", "KTStack.devMode"])
        let info = try JSONFileStore<SettingsSnapshotWriter.Info>.decoder.decode(
            SettingsSnapshotWriter.Info.self, from: Data(contentsOf: output.appendingPathComponent("snapshot.json"))
        )
        XCTAssertEqual(info.version, SettingsSnapshotWriter.formatVersion)
        XCTAssertEqual(info.createdAt, now)
        XCTAssertEqual(info.files, ["config/sites/sites.json", "config/php", "preferences.plist"])
    }
}
