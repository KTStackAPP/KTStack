import Foundation
import KTPlatformContracts
import XCTest
@testable import KTBackupPlugin

final class BackupRestorerTests: XCTestCase {
    private var root: URL!
    private var paths: BackupPaths!
    private var provider: SQLiteBackupProvider!
    private var store: BackupStore!

    override func setUpWithError() throws {
        root = try makeTemporaryDirectory()
        let databases = root.appendingPathComponent("db", isDirectory: true)
        try FileManager.default.createDirectory(at: databases, withIntermediateDirectories: true)
        try SQLiteBackupProvider.createDatabase("shop", in: databases, rows: 5)
        provider = SQLiteBackupProvider(databaseDirectory: databases)
        paths = BackupPaths(appSupportRoot: root.appendingPathComponent("support", isDirectory: true))
        store = BackupStore(paths: paths)
    }

    private func coordinator(site: BackupSiteFolder?) -> BackupCoordinator {
        let environment = FixedEnvironment(running: [.mysql], sites: site.map { [$0] } ?? [])
        let settings = SettingsSnapshotWriter(appSupportRoot: paths.appSupportRoot, defaultsDomain: nil)
        let runner = BackupPlanRunner(databases: provider, environment: environment, paths: paths, settings: settings)
        let factory = BackupDestinationFactory(paths: paths, secrets: MemorySecretStore(), transport: ScriptedTransport([]),
                                               bundledGoogleClient: nil)
        return BackupCoordinator(store: store, runner: runner, destinations: factory, logger: BackupLogger(fileURL: paths.logFile))
    }

    private func makeSite() throws -> BackupSiteFolder {
        let site = root.appendingPathComponent("sites/blog", isDirectory: true)
        try FileManager.default.createDirectory(at: site, withIntermediateDirectories: true)
        try Data("<h1>hi</h1>".utf8).write(to: site.appendingPathComponent("index.html"))
        return BackupSiteFolder(id: UUID(), name: "blog", root: site)
    }

    func testRunToLocalFolderThenRestoreEverything() async throws {
        let site = try makeSite()
        let folder = root.appendingPathComponent("target", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let destination = BackupDestination(name: "Disk", kind: .local, local: LocalFolderSettings(path: folder.path))
        var plan = BackupPlan(name: "Everything", databases: [BackupDatabaseSelection(engine: "mysql", database: "shop")])
        plan.includeSites = true
        plan.siteIDs = [site.id]
        plan.includeSettings = true
        plan.destinationID = destination.id
        let saved = plan
        try store.update { state in
            state.destinations = [destination]
            state.plans = [saved]
        }
        let run = await coordinator(site: site).run(planID: plan.id, trigger: .manual)
        XCTAssertEqual(run?.status, .succeeded, run?.message ?? "")
        XCTAssertEqual(store.snapshot.lastRun(for: plan.id)?.status, .succeeded)

        let client = LocalFolderClient(folder: folder)
        let objects = try await client.list(ownedBy: plan.id)
        XCTAssertEqual(objects.count, 1)
        let output = try makeTemporaryDirectory()
        let restorer = BackupRestorer(databases: provider, paths: paths, outputParent: output)
        let result = try await restorer.restore(objects[0], from: client)
        XCTAssertEqual(result.importedDatabases, ["mysql/shop"])
        XCTAssertEqual(result.failedDatabases, [])
        let extracted = try XCTUnwrap(result.extractedFolder)
        XCTAssertTrue(extracted.lastPathComponent.hasPrefix("KTStack Restore "))
        let siteArchives = try FileManager.default.contentsOfDirectory(atPath: extracted.appendingPathComponent("sites").path)
        XCTAssertEqual(siteArchives.count, 1)
        XCTAssertTrue(FileManager.default.fileExists(atPath: extracted.appendingPathComponent("settings/snapshot.json").path))
        XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: paths.restoreStaging.path), [])
        XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: paths.staging.path), [])
    }

    func testChecksumMismatchIsRejectedAndCleanedUp() async throws {
        let plan = BackupPlan(name: "Shop", databases: [BackupDatabaseSelection(engine: "mysql", database: "shop")])
        try store.update { $0.plans = [plan] }
        let run = await coordinator(site: nil).run(planID: plan.id, trigger: .manual)
        XCTAssertEqual(run?.status, .succeeded, run?.message ?? "")
        let client = LocalFolderClient(folder: paths.archives)
        var object = try await client.list(ownedBy: plan.id)[0]
        object.sha256 = String(repeating: "0", count: 64)
        let restorer = BackupRestorer(databases: provider, paths: paths, outputParent: try makeTemporaryDirectory())
        do {
            _ = try await restorer.restore(object, from: client)
            XCTFail("expected checksum failure")
        } catch {
            XCTAssertEqual(error as? BackupPipelineError, .checksumMismatch)
        }
        XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: paths.restoreStaging.path), [])
        XCTAssertEqual(provider.imported, [])
    }

    func testRemovedDestinationFailsTheRun() async throws {
        var plan = BackupPlan(name: "Shop", databases: [BackupDatabaseSelection(engine: "mysql", database: "shop")])
        plan.destinationID = UUID()
        let saved = plan
        try store.update { $0.plans = [saved] }
        let run = await coordinator(site: nil).run(planID: plan.id, trigger: .scheduled)
        XCTAssertEqual(run?.status, .failed)
        XCTAssertTrue(run?.message?.contains("removed") == true)
        let log = try String(contentsOf: paths.logFile, encoding: .utf8)
        XCTAssertTrue(log.contains("Plan \"Shop\" (scheduled): failed"))
    }

    func testResolveRejectsPathsEscapingTheArchive() throws {
        let content = try makeTemporaryDirectory()
        XCTAssertThrowsError(try BackupRestorer.resolve("../../etc", in: content))
        XCTAssertThrowsError(try BackupRestorer.resolve("/etc", in: content))
    }

    func testFactoryRequiresCredentials() throws {
        let factory = BackupDestinationFactory(paths: paths, secrets: MemorySecretStore(), transport: ScriptedTransport([]),
                                               bundledGoogleClient: nil)
        let s3 = BackupDestination(name: "S3", kind: .s3, s3: S3Settings(preset: .aws, endpoint: "", region: "us-east-1",
                                                                         bucket: "b", prefix: "", accessKeyID: "AK", usePathStyle: false))
        XCTAssertThrowsError(try factory.client(for: s3)) {
            guard case .missingCredentials = $0 as? BackupDestinationError else { return XCTFail("unexpected \($0)") }
        }
        let drive = BackupDestination(name: "Drive", kind: .googleDrive, googleDrive: GoogleDriveSettings())
        XCTAssertThrowsError(try factory.client(for: drive)) { XCTAssertEqual($0 as? GoogleAuthError, .clientMissing) }
        XCTAssertTrue(try factory.client(for: nil) is LocalFolderClient)
    }
}
