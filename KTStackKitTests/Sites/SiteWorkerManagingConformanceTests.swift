import KTPlatformContracts
import KTStackCore
import XCTest
@testable import KTStackKit

@MainActor
final class SiteWorkerManagingConformanceTests: XCTestCase {
    private let fm = FileManager.default
    private var root: URL!

    override func setUpWithError() throws {
        root = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("kd-worker-catalog-\(UUID().uuidString)", isDirectory: true)
    }

    override func tearDown() {
        try? fm.removeItem(at: root)
    }

    private func makeServerWithSite() throws -> (LocalServerController, Site) {
        let paths = AppSupportPaths(root: root)
        try paths.ensureDirectoryTree()
        let server = LocalServerController(bundleBinDir: URL(fileURLWithPath: "/dev/null"), paths: paths)
        let folder = root.appendingPathComponent("scratch/shop", isDirectory: true)
        try fm.createDirectory(at: folder, withIntermediateDirectories: true)
        try "<?php".write(to: folder.appendingPathComponent("index.php"), atomically: true, encoding: .utf8)
        let site = try server.registry.add(folder: folder)
        return (server, site)
    }

    func testWorkersRoundTripThroughTheCatalog() throws {
        let (server, site) = try makeServerWithSite()
        let queue = SiteWorkerPreset.laravelQueue.makeWorker()
        try server.setWorkers(site.id, [queue])
        XCTAssertEqual(server.catalog.sites.first?.workers, [queue])
        XCTAssertThrowsError(try server.setWorkers(site.id, [queue, queue]))
    }

    func testStartAndStopToggleTheEnabledFlagAndStatus() throws {
        let (server, site) = try makeServerWithSite()
        let queue = SiteWorkerPreset.laravelQueue.makeWorker()
        try server.setWorkers(site.id, [queue])
        XCTAssertEqual(server.workersState.status(of: queue.id).state, .stopped)

        server.startWorker(siteID: site.id, workerID: queue.id)
        XCTAssertEqual(server.registry.sites.first?.workers.first?.enabled, true)
        XCTAssertEqual(server.workersState.status(of: queue.id).state, .waitingForServer)

        server.stopWorker(siteID: site.id, workerID: queue.id)
        XCTAssertEqual(server.registry.sites.first?.workers.first?.enabled, false)
        XCTAssertEqual(server.workersState.status(of: queue.id).state, .stopped)
    }

    func testDetachedServerNeverDrivesTheLiveLaunchdStack() throws {
        let (server, site) = try makeServerWithSite()
        XCTAssertFalse(server.ownsRunningStack)
        XCTAssertFalse(server.isRunning, "a test instance must not adopt a KTStack stack running on this Mac")
        XCTAssertFalse(server.phpRunning)

        let queue = SiteWorkerPreset.laravelQueue.makeWorker()
        try server.setWorkers(site.id, [queue])
        server.startWorker(siteID: site.id, workerID: queue.id)
        server.setPHPVersion(site.id, site.phpVersion)
        XCTAssertFalse(server.isBusy, "registry changes on a detached instance never reconcile launchd")

        server.start()
        server.restartWorker(siteID: site.id, workerID: queue.id)
        XCTAssertFalse(server.isBusy)
        XCTAssertFalse(server.isRunning)
    }

    func testLogSourceIDMatchesTheCatalogFormat() throws {
        let (server, site) = try makeServerWithSite()
        let queue = SiteWorkerPreset.laravelQueue.makeWorker()
        try server.setWorkers(site.id, [queue])
        XCTAssertEqual(server.workerLogSourceID(siteID: site.id, workerID: queue.id), "site-\(site.domain)-worker-queue")
        XCTAssertNil(server.workerLogSourceID(siteID: site.id, workerID: UUID()))
    }
}
