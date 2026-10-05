import Foundation
import KTPlatformContracts
import XCTest
@testable import KTBackupPlugin

final class BackupPlanRunnerTests: XCTestCase {
    private var root: URL!
    private var databases: URL!
    private var paths: BackupPaths!

    override func setUpWithError() throws {
        root = try makeTemporaryDirectory()
        databases = root.appendingPathComponent("db", isDirectory: true)
        try FileManager.default.createDirectory(at: databases, withIntermediateDirectories: true)
        try SQLiteBackupProvider.createDatabase("shop", in: databases, rows: 20)
        paths = BackupPaths(appSupportRoot: root.appendingPathComponent("support", isDirectory: true))
    }

    private func runner(running: Set<DatabaseEngine> = [.mysql], delay: UInt64 = 0) -> (BackupPlanRunner, SQLiteBackupProvider) {
        let provider = SQLiteBackupProvider(databaseDirectory: databases, delay: delay)
        let settings = SettingsSnapshotWriter(appSupportRoot: paths.appSupportRoot, defaultsDomain: nil)
        return (BackupPlanRunner(databases: provider, environment: FixedEnvironment(running: running), paths: paths, settings: settings), provider)
    }

    private func plan(_ names: [String]) -> BackupPlan {
        BackupPlan(name: "Nightly", databases: names.map { BackupDatabaseSelection(engine: "mysql", database: $0) })
    }

    func testSuccessfulRunProducesVerifiedArchive() async throws {
        let (runner, provider) = runner()
        let outcome = try await runner.stage(plan(["shop"]), at: date("2026-05-10 02:00:00"))
        guard case let .staged(staged) = outcome else { return XCTFail("expected staged archive") }
        XCTAssertEqual(staged.items, [BackupRunItem(kind: .database, name: "mysql/shop", succeeded: true)])
        XCTAssertEqual(try FileDigest.sha256Hex(of: staged.archiveURL), staged.sha256)
        XCTAssertEqual(try FileDigest.size(of: staged.archiveURL), staged.sizeBytes)
        let extracted = try makeTemporaryDirectory()
        try ArchiveTool.unzip(staged.archiveURL, into: extracted)
        let top = extracted.appendingPathComponent((staged.fileName as NSString).deletingPathExtension)
        let manifest = try BackupArchiveManifest.read(in: top)
        XCTAssertEqual(manifest.databases.map(\.database), ["shop"])
        let dumpDir = top.appendingPathComponent(manifest.databases[0].path)
        XCTAssertEqual(try provider.importStagedBackup(at: dumpDir), ["shop"])
        let dump = try String(contentsOf: dumpDir.appendingPathComponent("shop.sql"), encoding: .utf8)
        XCTAssertTrue(dump.contains("row 19"))
        let leftovers = try FileManager.default.contentsOfDirectory(atPath: paths.staging.path)
        XCTAssertEqual(leftovers, [staged.fileName])
    }

    func testMissingDatabaseIsReportedPerItem() async throws {
        let (runner, _) = runner()
        guard case let .staged(staged) = try await runner.stage(plan(["shop", "gone"]), at: Date()) else {
            return XCTFail("expected staged archive")
        }
        XCTAssertEqual(staged.items.map(\.succeeded), [true, false])
        XCTAssertEqual(BackupRun.status(for: staged.items), .partial)
        XCTAssertTrue(staged.items[1].message?.contains("no longer exists") == true)
    }

    func testOnlyMissingDatabasesFailsTheRun() async throws {
        let (runner, _) = runner()
        do {
            _ = try await runner.stage(plan(["gone"]), at: Date())
            XCTFail("expected failure")
        } catch let error as BackupPipelineError {
            guard case .nothingBackedUp = error else { return XCTFail("unexpected \(error)") }
        }
    }

    func testEngineNotRunningSkips() async throws {
        let (runner, _) = runner(running: [])
        let outcome = try await runner.stage(plan(["shop"]), at: Date())
        XCTAssertEqual(outcome, .skipped(.engineStopped))
    }

    func testConcurrentRunForSamePlanIsRejected() async throws {
        let (runner, _) = runner(delay: 400_000_000)
        let nightly = plan(["shop"])
        async let first = runner.stage(nightly, at: Date())
        try await Task.sleep(nanoseconds: 100_000_000)
        do {
            _ = try await runner.stage(nightly, at: Date())
            XCTFail("expected rejection")
        } catch {
            XCTAssertEqual(error as? BackupPipelineError, .alreadyRunning)
        }
        guard case .staged = try await first else { return XCTFail("first run should finish") }
        let stillRunning = await runner.isRunning(nightly.id)
        XCTAssertFalse(stillRunning)
    }
}
