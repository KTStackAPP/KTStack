import XCTest
@testable import KTSitesPlugin

final class PHPFrameworkCacheTests: XCTestCase {
    func testRecheckSeesAFrameworkAddedAfterFirstDetection() async throws {
        let folder = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("kd-cache-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }

        let before = await PHPFrameworkCache.shared.framework(path: folder.path, docroot: folder.path)
        XCTAssertNotEqual(before, .laravel)

        try "<?php".write(to: folder.appendingPathComponent("artisan"), atomically: true, encoding: .utf8)
        let stale = await PHPFrameworkCache.shared.framework(path: folder.path, docroot: folder.path)
        XCTAssertEqual(stale, before, "the cache serves the first detection until invalidated")

        await PHPFrameworkCache.shared.invalidate(path: folder.path)
        let after = await PHPFrameworkCache.shared.framework(path: folder.path, docroot: folder.path)
        XCTAssertEqual(after, .laravel)
    }
}
