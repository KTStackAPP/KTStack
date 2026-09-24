import KTStackCore
import XCTest
@testable import KTStackKit

final class RestoreSiteSwapTests: XCTestCase {
    private var root: URL!
    private var paths: AppSupportPaths!
    private var siteFolder: URL!
    private let fm = FileManager.default

    override func setUpWithError() throws {
        root = try RestoreFixtureBuilder.makeTempDir("swap-root")
        paths = AppSupportPaths(root: root.appendingPathComponent("app", isDirectory: true))
        siteFolder = root.appendingPathComponent("sites/blog", isDirectory: true)
        try write("original", to: siteFolder.appendingPathComponent("index.php"))
    }

    override func tearDownWithError() throws {
        try? fm.removeItem(at: root)
    }

    private func write(_ text: String, to url: URL) throws {
        try fm.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try text.write(to: url, atomically: true, encoding: .utf8)
    }

    private func preparedFolder() throws -> URL {
        let staging = try RestoreStagingArea(paths: paths).make()
        let prepared = staging.appendingPathComponent("prepared", isDirectory: true)
        try write("restored", to: prepared.appendingPathComponent("index.php"))
        return prepared
    }

    private func siteIndex() throws -> String {
        try String(contentsOf: siteFolder.appendingPathComponent("index.php"), encoding: .utf8)
    }

    func testReplacedSiteSurvivesStagingDiscard() throws {
        let prepared = try preparedFolder()
        let record = try RestoreSiteSwap(paths: paths).swap(prepared: prepared, into: siteFolder)
        RestoreStagingArea(paths: paths).discard(prepared.deletingLastPathComponent())
        let replaced = try XCTUnwrap(record.replaced)
        XCTAssertTrue(fm.fileExists(atPath: replaced.appendingPathComponent("index.php").path))
        XCTAssertFalse(replaced.path.hasPrefix(prepared.deletingLastPathComponent().path))
    }

    func testUndoPutsOriginalBack() throws {
        let prepared = try preparedFolder()
        let swap = RestoreSiteSwap(paths: paths)
        let record = try swap.swap(prepared: prepared, into: siteFolder)
        XCTAssertEqual(try siteIndex(), "restored")
        RestoreStagingArea(paths: paths).discard(prepared.deletingLastPathComponent())
        try swap.undo(record)
        XCTAssertEqual(try siteIndex(), "original")
        XCTAssertFalse(fm.fileExists(atPath: record.discardedNew.path))
    }

    func testUndoWithoutPreviousFolderRemovesRestoredFiles() throws {
        try fm.removeItem(at: siteFolder)
        let swap = RestoreSiteSwap(paths: paths)
        let record = try swap.swap(prepared: try preparedFolder(), into: siteFolder)
        XCTAssertNil(record.replaced)
        try swap.undo(record)
        XCTAssertFalse(fm.fileExists(atPath: siteFolder.path))
    }

    func testFailedMoveRestoresOriginal() throws {
        let missingPrepared = root.appendingPathComponent("does-not-exist", isDirectory: true)
        XCTAssertThrowsError(try RestoreSiteSwap(paths: paths).swap(prepared: missingPrepared, into: siteFolder))
        XCTAssertEqual(try siteIndex(), "original")
    }

    func testCommitMovesReplacedToTrash() throws {
        let swap = RestoreSiteSwap(paths: paths)
        let record = try swap.swap(prepared: try preparedFolder(), into: siteFolder)
        XCTAssertNil(swap.commit(record))
        XCTAssertFalse(fm.fileExists(atPath: try XCTUnwrap(record.replaced).path))
        XCTAssertEqual(try siteIndex(), "restored")
    }

    func testSweepKeepsReplacedSites() throws {
        let record = try RestoreSiteSwap(paths: paths).swap(prepared: try preparedFolder(), into: siteFolder)
        RestoreStagingArea(paths: paths).sweepOrphans(keeping: [])
        XCTAssertTrue(fm.fileExists(atPath: try XCTUnwrap(record.replaced).path))
    }
}
