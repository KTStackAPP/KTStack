import KTStackCore
import XCTest
@testable import KTStackKit

@MainActor
final class IPCWorkerDispatchTests: XCTestCase {
    private var root: URL!

    override func setUpWithError() throws {
        root = FileManager.default.temporaryDirectory.appendingPathComponent("kt-ipc-workers-\(UUID().uuidString)", isDirectory: true)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: root)
    }

    private func makeDispatcher() throws -> (KTIPCCommandDispatcher, LocalServerController, Site) {
        let paths = AppSupportPaths(root: root.appendingPathComponent("app", isDirectory: true))
        try paths.ensureDirectoryTree()
        let folder = root.appendingPathComponent("shop", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        try "<?php".write(to: folder.appendingPathComponent("artisan"), atomically: true, encoding: .utf8)
        let server = LocalServerController(bundleBinDir: URL(fileURLWithPath: "/dev/null"), paths: paths)
        let site = try server.registry.add(folder: folder)
        try server.registry.setWorkers(site, [SiteWorkerPreset.laravelQueue.makeWorker()])
        let dispatcher = KTIPCCommandDispatcher(serverProvider: { server }, servicesProvider: { nil })
        return (dispatcher, server, site)
    }

    func testListReportsWorkersWithTheirState() async throws {
        let (dispatcher, _, site) = try makeDispatcher()
        let response = await dispatcher.dispatch(KTIPCRequest(id: "1", method: "workers.list", params: ["site": site.domain]))
        XCTAssertTrue(response.success, response.error ?? "")
        let list = try JSONDecoder().decode([KTIPCWorkerInfo].self, from: Data((response.result ?? "").utf8))
        XCTAssertEqual(list, [KTIPCWorkerInfo(
            site: site.domain, name: "queue", command: SiteWorkerPreset.laravelQueue.command,
            enabled: false, state: "stopped"
        )])
    }

    func testListRejectsAnUnknownSite() async throws {
        let (dispatcher, _, _) = try makeDispatcher()
        let response = await dispatcher.dispatch(KTIPCRequest(id: "2", method: "workers.list", params: ["site": "nope.test"]))
        XCTAssertFalse(response.success)
    }

    func testStartAndStopToggleTheWorker() async throws {
        let (dispatcher, server, site) = try makeDispatcher()
        let start = await dispatcher.dispatch(
            KTIPCRequest(id: "3", method: "workers.start", params: ["site": site.domain, "worker": "queue"])
        )
        XCTAssertTrue(start.success, start.error ?? "")
        XCTAssertTrue(start.result?.contains("starts with the server") == true, start.result ?? "")
        XCTAssertEqual(server.registry.sites.first?.workers.first?.enabled, true)

        let stop = await dispatcher.dispatch(
            KTIPCRequest(id: "4", method: "workers.stop", params: ["site": site.name, "worker": "queue"])
        )
        XCTAssertTrue(stop.success, stop.error ?? "")
        XCTAssertEqual(server.registry.sites.first?.workers.first?.enabled, false)
    }

    func testUnknownWorkerListsTheSiteWorkers() async throws {
        let (dispatcher, _, site) = try makeDispatcher()
        let response = await dispatcher.dispatch(
            KTIPCRequest(id: "5", method: "workers.restart", params: ["site": site.domain, "worker": "horizon"])
        )
        XCTAssertFalse(response.success)
        XCTAssertTrue(response.error?.contains("queue") == true, response.error ?? "")
    }

    func testRestartNeedsARunningWorker() async throws {
        let (dispatcher, _, site) = try makeDispatcher()
        let response = await dispatcher.dispatch(
            KTIPCRequest(id: "6", method: "workers.restart", params: ["site": site.domain, "worker": "queue"])
        )
        XCTAssertFalse(response.success)
    }
}
