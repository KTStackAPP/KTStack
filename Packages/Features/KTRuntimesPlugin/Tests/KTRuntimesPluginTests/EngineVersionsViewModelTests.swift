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
        for _ in 0 ..< 50 where vm.rows.isEmpty { await Task.yield() }
        XCTAssertEqual(vm.rows.first?.engine, .mysql)
    }
}

private enum TestError: Error { case boom }
