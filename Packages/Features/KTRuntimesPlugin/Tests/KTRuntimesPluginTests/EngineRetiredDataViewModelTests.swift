import KTPlatformContracts
import XCTest
@testable import KTRuntimesPlugin

@MainActor
final class EngineRetiredDataViewModelTests: XCTestCase {
    private func kept(_ engine: ServiceEngine, _ version: String) -> ServiceEngineRetiredData {
        ServiceEngineRetiredData(
            engine: engine,
            version: version,
            path: "/data/\(engine.rawValue)/.removed/\(version)-20260101-000000",
            removedAt: Date(timeIntervalSince1970: 0),
            sizeBytes: 4096
        )
    }

    private func snapshot(_ engine: ServiceEngine, installed: [String], running: Bool = false) -> ServiceEngineSnapshot {
        ServiceEngineSnapshot(
            engine: engine, active: installed.first, installed: installed, available: [],
            isRunning: running, isBusy: false, installInFlight: false, downloadFraction: [:]
        )
    }

    func testUninstallReportsKeptPathAndRefreshesKeptData() async throws {
        let engines = FakeEngines()
        engines.footprints["mysql-5.7"] = ServiceEngineDataFootprint(path: "/data/mysql/5.7", sizeBytes: 10)
        engines.retired = [kept(.mysql, "5.7")]
        let vm = EngineVersionsViewModel(engines: engines)
        let result = await vm.uninstall(.mysql, version: "5.7")
        XCTAssertEqual(try result.get(), "/data/mysql/5.7")
        XCTAssertEqual(vm.retiredData(.mysql), [kept(.mysql, "5.7")])
        XCTAssertTrue(vm.retiredData(.redis).isEmpty)
    }

    func testRestoreRequiresInstalledVersionAndStoppedEngine() {
        let item = kept(.mysql, "5.7")
        let notInstalled = EngineVersionsViewModel(engines: FakeEngines(snapshots: [snapshot(.mysql, installed: ["8.0"])]))
        XCTAssertNotNil(notInstalled.restoreBlockReason(item))
        let running = EngineVersionsViewModel(engines: FakeEngines(snapshots: [snapshot(.mysql, installed: ["8.0", "5.7"], running: true)]))
        XCTAssertNotNil(running.restoreBlockReason(item))
        let ready = EngineVersionsViewModel(engines: FakeEngines(snapshots: [snapshot(.mysql, installed: ["8.0", "5.7"])]))
        XCTAssertNil(ready.restoreBlockReason(item))
    }

    func testRestoreAndTrashRemoveEntryFromList() async {
        let engines = FakeEngines()
        engines.retired = [kept(.redis, "7.2"), kept(.redis, "7.0")]
        let vm = EngineVersionsViewModel(engines: engines)
        await vm.reloadRetired(.redis)
        XCTAssertEqual(vm.retiredData(.redis).count, 2)
        if case .failure = await vm.restore(kept(.redis, "7.2")) { XCTFail("expected success") }
        if case .failure = await vm.trash(kept(.redis, "7.0")) { XCTFail("expected success") }
        XCTAssertTrue(vm.retiredData(.redis).isEmpty)
        XCTAssertEqual(engines.restoreCalls.map(\.version), ["7.2"])
        XCTAssertEqual(engines.trashCalls.map(\.version), ["7.0"])
    }

    func testRetiredDataFailureIsReturned() async {
        let engines = FakeEngines()
        engines.retiredDataError = CocoaError(.fileWriteNoPermission)
        let vm = EngineVersionsViewModel(engines: engines)
        if case .success = await vm.trash(kept(.redis, "7.0")) { XCTFail("expected failure") }
    }

    func testUninstallMessageNamesKeptPathAndSize() {
        let footprint = ServiceEngineDataFootprint(path: "/data/mysql/5.7", sizeBytes: 2048)
        let message = RuntimesScreen.uninstallMessage(.mysql, version: "5.7", footprint: footprint)
        XCTAssertTrue(message.contains("/data/mysql/5.7"))
        XCTAssertTrue(message.contains("kept"))
        XCTAssertTrue(RuntimesScreen.uninstallMessage(.mysql, version: "5.7", footprint: nil).contains("no data"))
    }
}
