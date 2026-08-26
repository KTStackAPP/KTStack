import KTPlatformContracts
import XCTest
@testable import KTSitesPlugin

@MainActor
final class RestoreBackupModelTests: XCTestCase {
    func testSelectFileSurfacesInspectionError() {
        let restoring = FakeWordPressRestoring()
        struct InspectError: Error, LocalizedError { var errorDescription: String? { "bad backup" } }
        restoring.inspectResult = .failure(InspectError())
        let model = RestoreBackupModel(site: makeSite(), restoring: restoring)

        model.selectFile(URL(fileURLWithPath: "/tmp/backup.zip"), installed: ["8.4"])

        XCTAssertEqual(model.error, "bad backup")
        XCTAssertEqual(model.stage, .idle)
    }

    func testSelectFileFallsBackToFirstInstalledVersion() {
        let restoring = FakeWordPressRestoring()
        let site = makeSite(phpVersion: "8.1")
        let model = RestoreBackupModel(site: site, restoring: restoring)

        model.selectFile(URL(fileURLWithPath: "/tmp/backup.zip"), installed: ["8.3", "8.4"])

        XCTAssertEqual(model.phpVersion, "8.3")
        XCTAssertEqual(model.stage, .ready)
    }

    func testRestoreSurfacesWarnings() async {
        let restoring = FakeWordPressRestoring()
        restoring.restoreResult = .success(RestoreOutcome(domain: "example.test", warnings: ["search-replace skipped"]))
        let model = RestoreBackupModel(site: makeSite(), restoring: restoring)
        model.selectFile(URL(fileURLWithPath: "/tmp/backup.zip"), installed: ["8.4"])
        model.trusted = true

        model.restore()
        while model.stage == .running { await Task.yield() }

        XCTAssertEqual(model.warnings, ["search-replace skipped"])
        XCTAssertEqual(model.stage, .success)
    }

    func testRestoreRequiresTrustedConfirmation() {
        let restoring = FakeWordPressRestoring()
        let model = RestoreBackupModel(site: makeSite(), restoring: restoring)
        model.selectFile(URL(fileURLWithPath: "/tmp/backup.zip"), installed: ["8.4"])

        XCTAssertFalse(model.canRestore)
    }
}
