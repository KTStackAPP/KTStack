import KTPlatformContracts
import KTStackCore
import XCTest
@testable import KTSitesPlugin

@MainActor
final class SiteWorkersModelTests: XCTestCase {
    private var saved: [[SiteWorker]] = []

    private func makeModel(failWith error: Error? = nil) -> SiteWorkersModel {
        SiteWorkersModel { workers in
            if let error { throw error }
            self.saved.append(workers)
        }
    }

    func testLaravelPresetsHideOnesAlreadyAdded() {
        let model = makeModel()
        XCTAssertEqual(model.presets(isLaravel: false, current: []), [])
        XCTAssertEqual(model.presets(isLaravel: true, current: []), [.laravelQueue, .laravelScheduler])
        let queue = SiteWorkerPreset.laravelQueue.makeWorker()
        XCTAssertEqual(model.presets(isLaravel: true, current: [queue]), [.laravelScheduler])
    }

    func testAddingAPresetSavesItDisabled() throws {
        let model = makeModel()
        model.add(.laravelQueue, current: [])
        let worker = try XCTUnwrap(saved.last?.first)
        XCTAssertEqual(worker.name, "queue")
        XCTAssertEqual(worker.command, SiteWorkerPreset.laravelQueue.command)
        XCTAssertFalse(worker.enabled)
    }

    func testDraftAddsAWorkerWithANormalizedName() {
        let model = makeModel()
        model.beginAdd(current: [])
        model.draft?.name = " Horizon "
        model.draft?.command = "php artisan horizon"
        model.commitDraft(current: [])
        XCTAssertNil(model.draft)
        XCTAssertEqual(saved.last?.map(\.name), ["horizon"])
    }

    func testEditingKeepsTheWorkerIdentityAndEnabledFlag() {
        let model = makeModel()
        let queue = SiteWorker(name: "queue", command: "php artisan queue:work", enabled: true)
        model.beginEdit(queue)
        model.draft?.command = "php artisan queue:work --queue=high"
        model.commitDraft(current: [queue])
        XCTAssertEqual(saved.last, [SiteWorker(id: queue.id, name: "queue", command: "php artisan queue:work --queue=high", enabled: true)])
    }

    func testInvalidDraftKeepsTheEditorOpenWithAnError() {
        let model = makeModel()
        model.beginAdd(current: [])
        model.draft?.command = "php 'unterminated"
        model.commitDraft(current: [])
        XCTAssertNotNil(model.draft)
        XCTAssertNotNil(model.error)
        XCTAssertTrue(saved.isEmpty)
    }

    func testSaveFailureSurfacesTheError() {
        struct Failure: LocalizedError { var errorDescription: String? { "server busy" } }
        let model = makeModel(failWith: Failure())
        model.add(.laravelScheduler, current: [])
        XCTAssertEqual(model.error, "server busy")
    }

    func testRemoveDropsTheWorker() {
        let model = makeModel()
        let queue = SiteWorkerPreset.laravelQueue.makeWorker()
        let scheduler = SiteWorkerPreset.laravelScheduler.makeWorker()
        model.remove(queue, current: [queue, scheduler])
        XCTAssertEqual(saved.last, [scheduler])
    }
}

@MainActor
final class SitesViewModelWorkerTests: XCTestCase {
    private func makeVM(
        sites: [SiteSummary],
        workers: FakeSiteWorkers,
        running: Bool = true,
        route: @escaping @MainActor (SitesRoute) -> Void = { _ in }
    ) -> SitesViewModel {
        SitesViewModel(
            catalog: FakeSiteCatalog(catalog: SiteCatalogState(sites: sites, tld: "test")),
            server: FakeSiteServerControl(state: SiteServerState(isRunning: running, isBusy: false, lastError: nil, phpVersions: ["8.4"])),
            webEngine: FakeWebEngine(state: WebEngineState(apacheVersion: "2.4", installed: false, installing: false)),
            runtimes: FakeRuntimeManaging(state: RuntimeState()),
            sharing: FakeSiteSharing(),
            dns: FakeDNSResolving(state: DNSResolverState(status: .enabled, isBusy: false, lastError: nil, usesHelper: false, helperNeedsApproval: false)),
            provisioning: FakeSiteProvisioning(),
            workers: workers,
            route: route
        )
    }

    func testSummaryCountsActiveAndCrashedWorkers() {
        let queue = SiteWorker(name: "queue", command: "php artisan queue:work", enabled: true)
        let scheduler = SiteWorker(name: "scheduler", command: "php artisan schedule:work", enabled: true)
        let idle = SiteWorker(name: "idle", command: "php artisan horizon", enabled: false)
        let site = makeSite(workers: [queue, scheduler, idle])
        let vm = makeVM(sites: [site], workers: FakeSiteWorkers())
        vm.workers = SiteWorkersState(statuses: [
            queue.id: SiteWorkerStatus(state: .running),
            scheduler.id: SiteWorkerStatus(state: .crashed, lastExitStatus: 1),
        ])
        let summary = vm.workersSummary(for: site)
        XCTAssertEqual(summary, SiteWorkersSummary(total: 3, active: 1, failing: 1))
        XCTAssertEqual(summary.label, "1 worker failing")
        XCTAssertEqual(vm.workerStatus(idle).state, .stopped)
    }

    func testWorkerThatFailedToStartCountsAsFailing() {
        let queue = SiteWorker(name: "queue", command: "php artisan queue:work", enabled: true)
        let site = makeSite(workers: [queue])
        let vm = makeVM(sites: [site], workers: FakeSiteWorkers())
        vm.workers = SiteWorkersState(statuses: [queue.id: SiteWorkerStatus(state: .failed, message: "kt is missing")])
        XCTAssertEqual(vm.workersSummary(for: site), SiteWorkersSummary(total: 1, active: 0, failing: 1))
        XCTAssertEqual(vm.workerStatus(queue).message, "kt is missing")
    }

    func testEnabledWorkerWithoutStatusFollowsTheServer() {
        let queue = SiteWorker(name: "queue", command: "php artisan queue:work", enabled: true)
        XCTAssertEqual(makeVM(sites: [], workers: FakeSiteWorkers(), running: false).workerStatus(queue).state, .waitingForServer)
        XCTAssertEqual(makeVM(sites: [], workers: FakeSiteWorkers(), running: true).workerStatus(queue).state, .starting)
    }

    func testCommandsReachTheContract() throws {
        let fake = FakeSiteWorkers()
        let queue = SiteWorkerPreset.laravelQueue.makeWorker()
        let site = makeSite(workers: [queue])
        var routed: SitesRoute?
        let vm = makeVM(sites: [site], workers: fake, route: { routed = $0 })
        vm.startWorker(site.id, queue)
        vm.stopWorker(site.id, queue)
        vm.restartWorker(site.id, queue)
        try vm.setWorkers(site.id, [queue])
        vm.openWorkerLogs(site.id, queue)
        XCTAssertEqual(fake.startCalls, [queue.id])
        XCTAssertEqual(fake.stopCalls, [queue.id])
        XCTAssertEqual(fake.restartCalls, [queue.id])
        XCTAssertEqual(fake.setWorkersCalls.first?.1, [queue])
        guard case let .logs(sourceID) = routed else { return XCTFail("expected logs route") }
        XCTAssertEqual(sourceID, "worker-\(queue.id.uuidString)")
    }

    func testWorkerUpdatesFollowTheStream() async {
        let fake = FakeSiteWorkers()
        let vm = makeVM(sites: [], workers: fake)
        vm.startWorkerUpdates()
        let id = UUID()
        await Task.yield()
        fake.emit(SiteWorkersState(statuses: [id: SiteWorkerStatus(state: .running)]))
        for _ in 0..<50 where vm.workers.statuses[id] == nil {
            await Task.yield()
        }
        XCTAssertEqual(vm.workers.status(of: id).state, .running)
        vm.stopWorkerUpdates()
    }
}
