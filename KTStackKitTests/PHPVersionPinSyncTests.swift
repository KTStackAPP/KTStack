import KTStackCore
import XCTest

final class PHPVersionPinSyncTests: XCTestCase {
    func testManifestFullVersionsMatchLockFiles() throws {
        let arm64 = try Self.cellarVersions("scripts/php-bottle-pins.lock")
        let x86 = try Self.cellarVersions("scripts/php-bottle-pins-x86_64.lock")
        let php = RuntimeCatalog.manifest.filter { $0.language == .php }
        XCTAssertEqual(Set(php.map(\.version)), Set(arm64.keys))
        XCTAssertEqual(Set(php.map(\.version)), Set(x86.keys))
        for release in php {
            XCTAssertEqual(release.fullVersionByArch["arm64"], arm64[release.version], release.version)
            XCTAssertEqual(release.fullVersionByArch["x86_64"], x86[release.version], release.version)
        }
    }

    private static func cellarVersions(_ relPath: String) throws -> [String: String] {
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent(relPath)
        var map: [String: String] = [:]
        for line in try String(contentsOf: url, encoding: .utf8).split(whereSeparator: \.isNewline) {
            guard !line.hasPrefix("#") else { continue }
            let cols = line.split(separator: "\t", omittingEmptySubsequences: false)
            guard cols.count >= 2 else { continue }
            map[String(cols[0])] = String(cols[1])
        }
        return map
    }
}
