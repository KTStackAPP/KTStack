import KTPlatformContracts
import KTStackCore
import XCTest
@testable import KTRuntimesPlugin

@MainActor
final class RuntimesViewModelTests: XCTestCase {
    private func release(_ lang: RuntimeLanguage, _ version: String) -> RuntimeRelease {
        RuntimeRelease(language: lang, version: version, urlByArch: [:], sha256ByArch: [:])
    }

    private func makeVM(
        runtimes: FakeRuntimeManaging,
        web: FakeWebEngine? = nil,
        sites: FakePHPSites? = nil
    ) -> RuntimesViewModel {
        RuntimesViewModel(
            runtimes: runtimes,
            webEngine: web ?? FakeWebEngine(),
            phpSites: sites ?? FakePHPSites()
        )
    }

    func testInstalledEntriesPinDefaultThenNumericDescending() {
        let runtimes = FakeRuntimeManaging(state: RuntimeState(
            installed: [.php: ["8.1", "8.3", "8.2"]],
            defaults: [.php: "8.2"]
        ))
        let vm = makeVM(runtimes: runtimes)
        let entries = vm.installedEntries(.php)
        XCTAssertEqual(entries.map(\.version), ["8.2", "8.3", "8.1"])
        XCTAssertEqual(entries.first?.state, .active)
    }

    func testEntriesConcatInstalledThenAvailable() {
        let runtimes = FakeRuntimeManaging(state: RuntimeState(
            installed: [.php: ["8.1", "8.3"]],
            defaults: [.php: "8.1"]
        ))
        runtimes.releases = [release(.php, "7.4")]
        let vm = makeVM(runtimes: runtimes)
        XCTAssertEqual(vm.entries(.php).map(\.version), ["8.1", "8.3", "7.4"])
    }

    func testRailSummary() {
        let runtimes = FakeRuntimeManaging(state: RuntimeState(
            installed: [.php: ["8.3", "8.2"]],
            defaults: [.php: "8.2"]
        ))
        let vm = makeVM(runtimes: runtimes)
        XCTAssertEqual(vm.railSummary(.php), "2 installed · 8.2 default")
        XCTAssertEqual(vm.railSummary(.node), "Not installed")
    }

    func testEntriesAppendAvailableReleases() {
        let runtimes = FakeRuntimeManaging(state: RuntimeState(installed: [.php: ["8.3"]]))
        runtimes.releases = [release(.php, "7.4")]
        let vm = makeVM(runtimes: runtimes)
        let entries = vm.entries(.php)
        XCTAssertEqual(entries.map(\.version), ["8.3", "7.4"])
        XCTAssertEqual(entries.last?.state, .available)
    }

    func testMetaLinePHP() {
        let runtimes = FakeRuntimeManaging(state: RuntimeState(
            installed: [.php: ["8.3", "8.2", "7.4"]],
            defaults: [.php: "8.3"]
        ), eol: ["7.4"])
        let sites = FakePHPSites()
        sites.sitesByVersion = ["8.3": ["a.test", "b.test"], "8.2": ["c.test"]]
        let vm = makeVM(runtimes: runtimes, sites: sites)
        let byVersion = Dictionary(uniqueKeysWithValues: vm.installedEntries(.php).map { ($0.version, $0) })
        XCTAssertEqual(vm.metaLine(.php, byVersion["8.3"]!), "Default for new sites and terminals · 2 sites")
        XCTAssertEqual(vm.metaLine(.php, byVersion["8.2"]!), "1 site")
        XCTAssertEqual(vm.metaLine(.php, byVersion["7.4"]!), "Not used by any site · no security updates")
    }

    func testMetaLineNode() {
        let runtimes = FakeRuntimeManaging(state: RuntimeState(
            installed: [.node: ["24", "22"]],
            defaults: [.node: "24"]
        ))
        let vm = makeVM(runtimes: runtimes)
        let byVersion = Dictionary(uniqueKeysWithValues: vm.installedEntries(.node).map { ($0.version, $0) })
        XCTAssertEqual(vm.metaLine(.node, byVersion["24"]!), "Default for terminals · sites run their own server")
        XCTAssertEqual(vm.metaLine(.node, byVersion["22"]!), "Installed")
    }

    func testDownloadFractionMatchesVersionOnly() {
        let runtimes = FakeRuntimeManaging(state: RuntimeState(
            downloads: [.php: RuntimeDownloadProgress(version: "8.3", received: 5, total: 10)]
        ))
        let vm = makeVM(runtimes: runtimes)
        XCTAssertEqual(vm.downloadFraction(.php, "8.3"), 0.5)
        XCTAssertNil(vm.downloadFraction(.php, "8.2"))
    }

    func testIsDownloadingFalseWhenErrorPresent() {
        let runtimes = FakeRuntimeManaging(state: RuntimeState(
            downloads: [.php: RuntimeDownloadProgress(version: "8.3", received: 0, total: 10, error: "boom")]
        ))
        let vm = makeVM(runtimes: runtimes)
        XCTAssertFalse(vm.isDownloading(.php))
    }

    func testCommandsForward() {
        let runtimes = FakeRuntimeManaging()
        let vm = makeVM(runtimes: runtimes)
        let rel = release(.php, "8.3")
        vm.install(rel)
        vm.cancel(.php)
        vm.setDefault(.php, "8.3")
        XCTAssertEqual(runtimes.installCalls.first?.version, "8.3")
        XCTAssertEqual(runtimes.cancelCalls, [.php])
        XCTAssertEqual(runtimes.setDefaultCalls.first?.1, "8.3")
    }

    func testUninstallPHPReconciles() {
        let runtimes = FakeRuntimeManaging()
        let sites = FakePHPSites()
        let vm = makeVM(runtimes: runtimes, sites: sites)
        vm.uninstall(.php, "8.3")
        XCTAssertEqual(runtimes.uninstallCalls.first?.1, "8.3")
        XCTAssertEqual(sites.reconcileCalls, 1)
    }

    func testUninstallNodeSkipsReconcile() {
        let runtimes = FakeRuntimeManaging()
        let sites = FakePHPSites()
        let vm = makeVM(runtimes: runtimes, sites: sites)
        vm.uninstall(.node, "20")
        XCTAssertEqual(sites.reconcileCalls, 0)
    }

    func testUninstallPromptInUseVsFree() {
        let runtimes = FakeRuntimeManaging()
        let sites = FakePHPSites()
        sites.sitesByVersion = ["8.3": ["app.test", "shop.test"]]
        let vm = makeVM(runtimes: runtimes, sites: sites)
        let inUse = vm.uninstallPrompt(.php, "8.3")
        XCTAssertEqual(inUse.okLabel, "Remove anyway")
        XCTAssertTrue(inUse.message.contains("app.test"))
        let free = vm.uninstallPrompt(.php, "8.2")
        XCTAssertEqual(free.okLabel, "Remove")
    }

    func testIsEndOfLifeForwards() {
        let runtimes = FakeRuntimeManaging(eol: ["7.4"])
        let vm = makeVM(runtimes: runtimes)
        XCTAssertTrue(vm.isEndOfLife(.php, "7.4"))
        XCTAssertFalse(vm.isEndOfLife(.php, "8.3"))
    }

    func testWebEngineReflectedAndInstallForwards() {
        let runtimes = FakeRuntimeManaging()
        let web = FakeWebEngine(state: WebEngineState(apacheVersion: "2.4.62", installed: true, installing: false))
        let vm = makeVM(runtimes: runtimes, web: web)
        XCTAssertTrue(vm.webEngine.installed)
        vm.installApache()
        XCTAssertEqual(web.installApacheCalls, 1)
    }

    func testStatePicksUpStreamEmission() async {
        let runtimes = FakeRuntimeManaging()
        let vm = makeVM(runtimes: runtimes)
        runtimes.emit(RuntimeState(installed: [.php: ["8.4"]]))
        for _ in 0..<50 where vm.entries(.php).isEmpty {
            await Task.yield()
        }
        XCTAssertEqual(vm.entries(.php).map(\.version), ["8.4"])
    }
}
