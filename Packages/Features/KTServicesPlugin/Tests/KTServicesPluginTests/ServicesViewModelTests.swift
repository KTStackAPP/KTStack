import KTPlatformContracts
import XCTest
@testable import KTServicesPlugin

@MainActor
final class ServicesViewModelTests: XCTestCase {
    private func makeVM(
        services: FakeServiceManaging,
        engines: FakeEngineVersionManaging = FakeEngineVersionManaging(),
        dns: FakeDNSResolver = FakeDNSResolver(),
        caTrust: FakeCATrust = FakeCATrust()
    ) -> ServicesViewModel {
        ServicesViewModel(services: services, engines: engines, dns: dns, caTrust: caTrust)
    }

    private func engineSnapshot(_ engine: ServiceEngine, active: String?, installed: [String]) -> ServiceEngineSnapshot {
        ServiceEngineSnapshot(
            engine: engine, active: active, installed: installed, available: [],
            isRunning: false, isBusy: false, installInFlight: false, downloadFraction: [:]
        )
    }

    func testRowsKeepServiceOrder() {
        let states = [makeState(.nginx), makeState(.dnsmasq), makeState(.phpFpm)]
        let vm = makeVM(services: FakeServiceManaging(states: states))
        XCTAssertEqual(vm.rows(for: [.nginx, .dnsmasq]).map(\.id), [.nginx, .dnsmasq])
    }

    func testDBEntriesJoinEngineSnapshots() throws {
        let states = [makeState(.mysql), makeState(.postgres), makeState(.redis), makeState(.mongodb)]
        let engines = FakeEngineVersionManaging(snapshots: [
            engineSnapshot(.mysql, active: "8.4", installed: ["8.4", "8.0"]),
            engineSnapshot(.redis, active: "7.2", installed: ["7.2"]),
        ])
        let vm = makeVM(services: FakeServiceManaging(states: states), engines: engines)
        let entries = vm.dbEntries
        XCTAssertEqual(entries.map(\.id), [.mysql, .postgres, .redis, .mongodb])
        let mysql = try XCTUnwrap(entries.first { $0.id == .mysql })
        XCTAssertEqual(mysql.active, "8.4")
        XCTAssertEqual(mysql.installed, ["8.4", "8.0"])
        // engine snapshot thiếu → installed rỗng, active nil
        let postgres = try XCTUnwrap(entries.first { $0.id == .postgres })
        XCTAssertTrue(postgres.installed.isEmpty)
        XCTAssertNil(postgres.active)
    }

    func testLogSourceID() {
        XCTAssertEqual(ServicesViewModel.logSourceID(.nginx), "nginx-error")
        XCTAssertEqual(ServicesViewModel.logSourceID(.mysql), "mysql")
        XCTAssertEqual(ServicesViewModel.logSourceID(.postgres), "postgres")
        XCTAssertEqual(ServicesViewModel.logSourceID(.redis), "redis")
        XCTAssertEqual(ServicesViewModel.logSourceID(.mongodb), "mongodb")
        XCTAssertEqual(ServicesViewModel.logSourceID(.mailpit), "mailpit")
        XCTAssertNil(ServicesViewModel.logSourceID(.phpFpm))
        XCTAssertNil(ServicesViewModel.logSourceID(.dnsmasq))
    }

    func testSetActiveThrowsReturnsFailure() {
        let engines = FakeEngineVersionManaging()
        engines.setActiveShouldThrow = true
        let vm = makeVM(services: FakeServiceManaging(states: [makeState(.redis)]), engines: engines)
        if case .success = vm.setActive(.redis, version: "7.2") {
            XCTFail("expected failure")
        }
        XCTAssertEqual(engines.setActiveCalls.map(\.0), [.redis])
    }

    func testSetActiveOnNonEngineReturnsFailure() {
        let vm = makeVM(services: FakeServiceManaging(states: [makeState(.nginx)]))
        if case .success = vm.setActive(.nginx, version: "x") {
            XCTFail("expected failure for non-engine service")
        }
    }

    func testCommandsForwardID() {
        let services = FakeServiceManaging(states: [makeState(.nginx)])
        let vm = makeVM(services: services)
        vm.toggle(.nginx)
        vm.restart(.mysql)
        vm.install(.postgres)
        vm.cancelInstall(.postgres)
        vm.resetData(.mongodb)
        vm.startAll()
        vm.restartAll()
        XCTAssertEqual(services.toggleCalls, [.nginx])
        XCTAssertEqual(services.restartCalls, [.mysql])
        XCTAssertEqual(services.installCalls, [.postgres])
        XCTAssertEqual(services.cancelInstallCalls, [.postgres])
        XCTAssertEqual(services.resetDataCalls, [.mongodb])
        XCTAssertEqual(services.startAllCalls, 1)
        XCTAssertEqual(services.restartAllCalls, 1)
    }

    func testStreamPushUpdatesPublished() async {
        let services = FakeServiceManaging(states: [makeState(.nginx, health: .stopped)])
        let vm = makeVM(services: services)
        services.emit([makeState(.nginx, health: .running)])
        for _ in 0 ..< 50 where vm.services.first?.health != .running {
            await Task.yield()
        }
        XCTAssertEqual(vm.services.first?.health, .running)
    }
}
