import KTStackCore
import XCTest
@testable import KTStackKit

final class RestoreStagingSweepTests: XCTestCase {
    private var root: URL!
    private var paths: AppSupportPaths!

    override func setUpWithError() throws {
        root = try RestoreFixtureBuilder.makeTempDir("sweep-root")
        paths = AppSupportPaths(root: root)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: root)
    }

    func testMakeCreatesPrivateStaging() throws {
        let area = RestoreStagingArea(paths: paths)
        let staging = try area.make(id: "abc")
        XCTAssertTrue(FileManager.default.fileExists(atPath: staging.path))
        let perms = try FileManager.default.attributesOfItem(atPath: staging.path)[.posixPermissions] as? NSNumber
        XCTAssertEqual(perms?.int16Value, 0o700)
    }

    func testSweepRemovesOrphansKeepingActive() throws {
        let area = RestoreStagingArea(paths: paths)
        let active = try area.make(id: "active")
        let orphanA = try area.make(id: "orphan-a")
        let orphanB = try area.make(id: "orphan-b")

        area.sweepOrphans(keeping: ["active"])

        XCTAssertTrue(FileManager.default.fileExists(atPath: active.path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: orphanA.path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: orphanB.path))
    }

    func testSweepEmptyKeepReclaimsEverything() throws {
        let area = RestoreStagingArea(paths: paths)
        _ = try area.make(id: "crashed-1")
        _ = try area.make(id: "crashed-2")

        area.sweepOrphans(keeping: [])

        let remaining = (try? FileManager.default.contentsOfDirectory(atPath: paths.restoreStagingRoot.path)) ?? []
        XCTAssertTrue(remaining.isEmpty)
    }
}
