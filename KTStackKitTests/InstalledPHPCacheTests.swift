import XCTest
@testable import KTStackKit

final class InstalledPHPCacheTests: XCTestCase {
    private func installFakePHP(_ version: String, in root: URL) throws {
        let binary = BundledPHP.fpmBinary(for: version, php: root)
        try FileManager.default.createDirectory(at: binary.deletingLastPathComponent(), withIntermediateDirectories: true)
        FileManager.default.createFile(atPath: binary.path, contents: Data(), attributes: [.posixPermissions: 0o755])
    }

    func testCachedVersionsFollowInstallAndUninstall() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let cache = InstalledPHPCache()
        XCTAssertEqual(cache.versions(php: root), [])
        try installFakePHP("8.3", in: root)
        XCTAssertEqual(cache.versions(php: root), ["8.3"])
        try installFakePHP("8.4", in: root)
        XCTAssertEqual(cache.versions(php: root), ["8.3", "8.4"])
        try FileManager.default.removeItem(at: root.appendingPathComponent("8.3"))
        XCTAssertEqual(cache.versions(php: root), ["8.4"])
    }
}
