import KTPlatformContracts
import XCTest
@testable import KTRuntimesPlugin

@MainActor
final class EngineVersionsViewModelTests: XCTestCase {
    private func snapshot(
        _ engine: ServiceEngine,
        active: String? = nil,
        installed: [String] = [],
        available: [String] = [],
        isRunning: Bool = false,
        isBusy: Bool = false,
        installInFlight: Bool = false,
        downloadFraction: [String: Double] = [:]
    ) -> ServiceEngineSnapshot {
        ServiceEngineSnapshot(
            engine: engine,
            active: active,
            installed: installed,
            available: available.map { ServiceEngineRelease(engine: engine, version: $0) },
            isRunning: isRunning,
            isBusy: isBusy,
            installInFlight: installInFlight,
            downloadFraction: downloadFraction
        )
    }

    func testRowsMarkActiveInstalledAvailable() {
        let engines = FakeEngines(snapshots: [
            snapshot(.mysql, active: "8.0", installed: ["8.0", "5.7"], available: ["8.4"]),
        ])
        let vm = EngineVersionsViewModel(engines: engines)
        let states = vm.rows.map(\.state)
        XCTAssertEqual(states, [.active, .installed, .available])
        XCTAssertEqual(vm.rows.map(\.version), ["8.0", "5.7", "8.4"])
    }

    func testRowsForEnginePinActiveThenNumericDescending() {
        let engines = FakeEngines(snapshots: [
            snapshot(.mysql, active: "8.0", installed: ["5.7", "8.4", "8.0"], available: ["9.0"]),
        ])
        let vm = EngineVersionsViewModel(engines: engines)
        let rows = vm.rows(for: .mysql)
        XCTAssertEqual(rows.map(\.version), ["8.0", "8.4", "5.7", "9.0"])
        XCTAssertEqual(rows.first?.state, .active)
        XCTAssertEqual(rows.last?.state, .available)
    }

    func testEngineRailSummaryAndRunning() {
        let engines = FakeEngines(snapshots: [
            snapshot(.mysql, active: "8.4", installed: ["8.4"], isRunning: true),
            snapshot(.redis, installed: []),
        ])
        let vm = EngineVersionsViewModel(engines: engines)
        XCTAssertEqual(vm.railSummary(.mysql), "8.4 active")
        XCTAssertTrue(vm.isRunning(.mysql))
        XCTAssertEqual(vm.railSummary(.redis), "Not installed")
        XCTAssertFalse(vm.isRunning(.mongodb))
    }

    func testSwitchBlockReason() {
        let running = FakeEngines(snapshots: [snapshot(.mysql, active: "8.4", installed: ["8.4"], isRunning: true)])
        XCTAssertEqual(EngineVersionsViewModel(engines: running).switchBlockReason(.mysql), "Stop MySQL 8.4 to switch")

        let busy = FakeEngines(snapshots: [snapshot(.mysql, active: "8.4", installed: ["8.4"], isBusy: true)])
        XCTAssertEqual(EngineVersionsViewModel(engines: busy).switchBlockReason(.mysql), "Stop MySQL 8.4 to switch")

        let installing = FakeEngines(snapshots: [snapshot(.mysql, installed: ["8.4"], installInFlight: true)])
        XCTAssertEqual(EngineVersionsViewModel(engines: installing).switchBlockReason(.mysql), "Installing…")

        let idle = FakeEngines(snapshots: [snapshot(.mysql, active: "8.4", installed: ["8.4"])])
        XCTAssertNil(EngineVersionsViewModel(engines: idle).switchBlockReason(.mysql))
    }

    func testMetaLine() {
        let running = FakeEngines(snapshots: [
            snapshot(.mysql, active: "8.4", installed: ["8.4", "8.0"], isRunning: true),
        ])
        let vm = EngineVersionsViewModel(engines: running)
        let rows = vm.rows(for: .mysql)
        XCTAssertEqual(vm.metaLine(rows[0]), "Running · data stored per version")
        XCTAssertEqual(vm.metaLine(rows[1]), "Stop MySQL 8.4 to switch")

        let stopped = FakeEngines(snapshots: [snapshot(.mysql, active: "8.4", installed: ["8.4"])])
        let stoppedVM = EngineVersionsViewModel(engines: stopped)
        XCTAssertEqual(stoppedVM.metaLine(stoppedVM.rows(for: .mysql)[0]), "Stopped · data stored per version")
    }

    func testSnapshotLookup() {
        let engines = FakeEngines(snapshots: [snapshot(.redis, installed: ["7.2"], isRunning: true)])
        let vm = EngineVersionsViewModel(engines: engines)
        XCTAssertTrue(vm.snapshot(.redis)?.isRunning ?? false)
        XCTAssertNil(vm.snapshot(.mongodb))
    }

    func testInstallCancelToggleForward() {
        let engines = FakeEngines()
        let vm = EngineVersionsViewModel(engines: engines)
        let rel = ServiceEngineRelease(engine: .postgres, version: "16")
        vm.install(rel)
        vm.cancelInstall(rel)
        vm.toggle(.postgres)
        XCTAssertEqual(engines.installCalls.first?.version, "16")
        XCTAssertEqual(engines.cancelCalls.first?.version, "16")
        XCTAssertEqual(engines.toggleCalls, [.postgres])
    }

    func testSetActiveSuccessAndFailure() {
        let engines = FakeEngines()
        let vm = EngineVersionsViewModel(engines: engines)
        if case .failure = vm.setActive(.mysql, version: "8.0") { XCTFail("expected success") }
        engines.setActiveError = TestError.boom
        if case .success = vm.setActive(.mysql, version: "5.7") { XCTFail("expected failure") }
        XCTAssertEqual(engines.setActiveCalls.count, 2)
    }

    func testUninstallSuccessAndFailure() {
        let engines = FakeEngines()
        let vm = EngineVersionsViewModel(engines: engines)
        if case .failure = vm.uninstall(.mongodb, version: "7.0") { XCTFail("expected success") }
        engines.uninstallError = TestError.boom
        if case .success = vm.uninstall(.mongodb, version: "6.0") { XCTFail("expected failure") }
        XCTAssertEqual(engines.uninstallCalls.count, 2)
    }

    func testSnapshotsPickUpStreamEmission() async {
        let engines = FakeEngines()
        let vm = EngineVersionsViewModel(engines: engines)
        engines.emit([snapshot(.mysql, installed: ["8.0"])])
        for _ in 0..<50 where vm.rows.isEmpty {
            await Task.yield()
        }
        XCTAssertEqual(vm.rows.first?.engine, .mysql)
    }
}

private enum TestError: Error { case boom }
