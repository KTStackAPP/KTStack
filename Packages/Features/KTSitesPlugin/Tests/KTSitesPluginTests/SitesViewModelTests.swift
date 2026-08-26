import KTPlatformContracts
import KTStackCore
import XCTest
@testable import KTSitesPlugin

@MainActor
final class SitesViewModelTests: XCTestCase {
    private struct Harness {
        let vm: SitesViewModel
        let catalog: FakeSiteCatalog
        let server: FakeSiteServerControl
        let sharing: FakeSiteSharing
        let dns: FakeDNSResolving
        let provisioning: FakeSiteProvisioning
    }

    private func makeVM(
        sites: [SiteSummary] = [],
        tld: String = "test",
        server: SiteServerState = SiteServerState(isRunning: true, isBusy: false, lastError: nil, phpVersions: ["8.3", "8.4"]),
        runtimes: RuntimeState = RuntimeState(defaults: [.php: "8.4"]),
        catalog: FakeSiteCatalog? = nil,
        serverControl: FakeSiteServerControl? = nil
    ) -> Harness {
        let catalogFake = catalog ?? FakeSiteCatalog(catalog: SiteCatalogState(sites: sites, tld: tld))
        let serverFake = serverControl ?? FakeSiteServerControl(state: server)
        let webEngine = FakeWebEngine(state: WebEngineState(apacheVersion: "2.4", installed: false, installing: false))
        let runtimesFake = FakeRuntimeManaging(state: runtimes)
        let sharing = FakeSiteSharing()
        let dns = FakeDNSResolving(state: DNSResolverState(status: .enabled, isBusy: false, lastError: nil, usesHelper: false, helperNeedsApproval: false))
        let provisioning = FakeSiteProvisioning()
        let vm = SitesViewModel(
            catalog: catalogFake,
            server: serverFake,
            webEngine: webEngine,
            runtimes: runtimesFake,
            sharing: sharing,
            dns: dns,
            provisioning: provisioning,
            route: { _ in }
        )
        return Harness(vm: vm, catalog: catalogFake, server: serverFake, sharing: sharing, dns: dns, provisioning: provisioning)
    }

    func testInitialStateComesFromContractSnapshots() {
        let site = makeSite()
        let vm = makeVM(sites: [site], tld: "test").vm
        XCTAssertEqual(vm.sites, [site])
        XCTAssertEqual(vm.tld, "test")
        XCTAssertTrue(vm.server.isRunning)
    }

    func testDefaultPHPPrefersRuntimeDefault() {
        let vm = makeVM(runtimes: RuntimeState(defaults: [.php: "8.3"])).vm
        XCTAssertEqual(vm.defaultPHP, "8.3")
    }

    func testDefaultPHPFallsBackToLastServerVersion() {
        let vm = makeVM(
            server: SiteServerState(isRunning: true, isBusy: false, lastError: nil, phpVersions: ["8.2", "8.3"]),
            runtimes: RuntimeState(defaults: [:])
        ).vm
        XCTAssertEqual(vm.defaultPHP, "8.3")
    }

    func testSetNodePortThrowsOnDuplicate() {
        let first = makeSite(name: "a", domain: "a.test", kind: .node, nodePort: 3000)
        let second = makeSite(name: "b", domain: "b.test", kind: .node, nodePort: nil)
        let h = makeVM(sites: [first, second])
        let vm = h.vm
        let catalog = h.catalog

        XCTAssertThrowsError(try vm.setNodePort(second.id, 3000)) { error in
            XCTAssertTrue(error is SiteActionError)
        }
        XCTAssertTrue(catalog.setNodePortCalls.isEmpty)
    }

    func testSetNodePortSucceedsWhenPortIsFree() throws {
        let site = makeSite(kind: .node, nodePort: nil)
        let h = makeVM(sites: [site])
        let vm = h.vm
        let catalog = h.catalog

        try vm.setNodePort(site.id, 3001)
        XCTAssertEqual(catalog.setNodePortCalls.first?.1, 3001)
    }

    func testOpenLogsRoutesWithAccessSourceID() {
        var routed: SitesRoute?
        let site = makeSite(domain: "a.test")
        let catalogFake = FakeSiteCatalog(catalog: SiteCatalogState(sites: [site], tld: "test"))
        let vm = SitesViewModel(
            catalog: catalogFake,
            server: FakeSiteServerControl(state: SiteServerState(isRunning: true, isBusy: false, lastError: nil, phpVersions: ["8.4"])),
            webEngine: FakeWebEngine(state: WebEngineState(apacheVersion: "2.4", installed: false, installing: false)),
            runtimes: FakeRuntimeManaging(state: RuntimeState()),
            sharing: FakeSiteSharing(),
            dns: FakeDNSResolving(state: DNSResolverState(status: .enabled, isBusy: false, lastError: nil, usesHelper: false, helperNeedsApproval: false)),
            provisioning: FakeSiteProvisioning(),
            route: { routed = $0 }
        )
        vm.openLogs(site)
        guard case let .logs(sourceID) = routed else { return XCTFail("expected logs route") }
        XCTAssertEqual(sourceID, "site-a.test-access")
    }

    func testRemoveDelegatesToProvisioning() async throws {
        let site = makeSite(databaseName: "db_a")
        let h = makeVM(sites: [site])
        let vm = h.vm
        let provisioning = h.provisioning

        try await vm.remove(site, deleteFolder: true, dropDatabase: true)
        XCTAssertEqual(provisioning.removeCalls.first?.0, site.id)
        XCTAssertEqual(provisioning.removeCalls.first?.1, true)
        XCTAssertEqual(provisioning.removeCalls.first?.2, true)
    }

    func testRemovePropagatesError() async {
        let site = makeSite()
        let h = makeVM(sites: [site])
        let vm = h.vm
        let provisioning = h.provisioning
        provisioning.removeError = NSError(domain: "test", code: 1)

        do {
            try await vm.remove(site, deleteFolder: false, dropDatabase: false)
            XCTFail("expected throw")
        } catch {
            XCTAssertEqual((error as NSError).domain, "test")
        }
    }

    func testNodeProbingOnlyPollsNodeSitesWithPort() async {
        let nodeSite = makeSite(name: "node", domain: "node.test", kind: .node, nodePort: 3000)
        let phpSite = makeSite(name: "php", domain: "php.test", kind: .php)
        let nodeWithoutPort = makeSite(name: "bare", domain: "bare.test", kind: .node, nodePort: nil)
        let server = FakeSiteServerControl(state: SiteServerState(isRunning: true, isBusy: false, lastError: nil, phpVersions: ["8.4"]))
        server.nodeProbeResult = true
        let h = makeVM(sites: [nodeSite, phpSite, nodeWithoutPort], serverControl: server)
        let vm = h.vm
        let serverFake = h.server

        vm.startNodeProbing()
        try? await Task.sleep(nanoseconds: 100_000_000)
        vm.stopNodeProbing()

        XCTAssertEqual(serverFake.probeUpstreamCalls.map(\.port), [3000])
        XCTAssertEqual(serverFake.probeUpstreamCalls.map(\.host), ["127.0.0.1"])
    }

    func testNodeProbePrunesSiteThatLosesPort() async {
        let id = UUID()
        let node = makeSite(id: id, name: "node", domain: "node.test", kind: .node, nodePort: 3000)
        let server = FakeSiteServerControl(state: SiteServerState(isRunning: true, isBusy: false, lastError: nil, phpVersions: ["8.4"]))
        server.nodeProbeResult = true
        let h = makeVM(sites: [node], serverControl: server)
        let vm = h.vm
        let catalog = h.catalog

        await vm.refreshNodeRunning()
        XCTAssertEqual(vm.nodeRunning[id], true)

        let bare = makeSite(id: id, name: "node", domain: "node.test", kind: .node, nodePort: nil)
        catalog.emit(SiteCatalogState(sites: [bare], tld: "test"))
        try? await Task.sleep(nanoseconds: 80_000_000)

        await vm.refreshNodeRunning()
        XCTAssertNil(vm.nodeRunning[id])
    }

    func testEnableDisableResetDNSDelegate() {
        let h = makeVM()
        let vm = h.vm
        let dns = h.dns
        vm.enableDNS()
        vm.disableDNS()
        vm.resetDNS()
        vm.refreshDNS()
        XCTAssertEqual(dns.enableCalls, 1)
        XCTAssertEqual(dns.disableCalls, 1)
        XCTAssertEqual(dns.resetCalls, 1)
        XCTAssertEqual(dns.refreshCalls, 1)
    }

    func testStartStopShareDelegatesToSharingManager() {
        let site = makeSite()
        let h = makeVM(sites: [site])
        let vm = h.vm
        let sharing = h.sharing
        vm.startShare(site)
        vm.stopShare(siteID: site.id)
        XCTAssertEqual(sharing.startShareCalls.first?.id, site.id)
        XCTAssertEqual(sharing.stopShareCalls, [site.id])
    }
}
