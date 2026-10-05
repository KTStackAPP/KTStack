import Foundation
import XCTest
@testable import KTBackupPlugin

final class SiteArchiverTests: XCTestCase {
    func testExcludeMatcherHandlesNamesGlobsAndAnchoredPaths() {
        let matcher = ExcludeMatcher(patterns: ["node_modules", "*.log", "/storage/framework/cache/", " "])
        XCTAssertTrue(matcher.isExcluded("node_modules"))
        XCTAssertTrue(matcher.isExcluded("packages/ui/node_modules/react/index.js"))
        XCTAssertTrue(matcher.isExcluded("storage/logs/laravel.log"))
        XCTAssertTrue(matcher.isExcluded("storage/framework/cache/data/x"))
        XCTAssertFalse(matcher.isExcluded("app/storage/framework/cache/x"))
        XCTAssertFalse(matcher.isExcluded("app/Logger.php"))
        XCTAssertEqual(matcher.patterns.count, 3)
    }

    func testArchiveHonoursExcludesAndDropsSymlinksOutsideTheSite() throws {
        let base = try makeTemporaryDirectory()
        let site = base.appendingPathComponent("shop", isDirectory: true)
        let fileManager = FileManager.default
        for directory in ["app/Models", "node_modules/left-pad", "public", "storage/logs"] {
            try fileManager.createDirectory(at: site.appendingPathComponent(directory), withIntermediateDirectories: true)
        }
        try Data("<?php".utf8).write(to: site.appendingPathComponent("app/Models/User.php"))
        try Data("x".utf8).write(to: site.appendingPathComponent("node_modules/left-pad/index.js"))
        try Data("log".utf8).write(to: site.appendingPathComponent("storage/logs/app.log"))
        try Data("secret".utf8).write(to: base.appendingPathComponent("outside.txt"))
        try fileManager.createSymbolicLink(atPath: site.appendingPathComponent("public/storage").path, withDestinationPath: "../storage")
        try fileManager.createSymbolicLink(atPath: site.appendingPathComponent("public/leak").path,
                                           withDestinationPath: base.appendingPathComponent("outside.txt").path)
        let folder = BackupSiteFolder(id: UUID(), name: "My Shop!", root: site)
        let collected = try SiteFileCollector(matcher: ExcludeMatcher(patterns: ["node_modules", "*.log"])).collect(root: site)
        XCTAssertEqual(collected, ["app", "app/Models", "app/Models/User.php", "public", "public/storage", "storage", "storage/logs"])

        let archive = base.appendingPathComponent(SiteArchiver.archiveName(for: folder))
        XCTAssertTrue(archive.lastPathComponent.hasPrefix("My-Shop--"))
        try SiteArchiver(matcher: ExcludeMatcher(patterns: ["node_modules", "*.log"])).archive(folder, to: archive)
        let extracted = try makeTemporaryDirectory()
        try ArchiveTool.run(ArchiveTool.tarPath, ["-xzf", archive.path, "-C", extracted.path])
        XCTAssertTrue(fileManager.fileExists(atPath: extracted.appendingPathComponent("app/Models/User.php").path))
        XCTAssertFalse(fileManager.fileExists(atPath: extracted.appendingPathComponent("node_modules").path))
        XCTAssertFalse(fileManager.fileExists(atPath: extracted.appendingPathComponent("public/leak").path))
        let link = try fileManager.destinationOfSymbolicLink(atPath: extracted.appendingPathComponent("public/storage").path)
        XCTAssertEqual(link, "../storage")
    }

    func testMissingSiteFolderFails() {
        XCTAssertThrowsError(try SiteFileCollector(matcher: ExcludeMatcher(patterns: [])).collect(root: URL(fileURLWithPath: "/nonexistent/site")))
    }
}
