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

    func testEntriesSortDescendingWithDefaultActive() {
        let runtimes = FakeRuntimeManaging(state: RuntimeState(
            installed: [.php: ["8.1", "8.3", "8.2"]],
            defaults: [.php: "8.2"]
        ))
        let vm = makeVM(runtimes: runtimes)
        let entries = vm.entries(.php)
        XCTAssertEqual(entries.map(\.version), ["8.3", "8.2", "8.1"])
        XCTAssertEqual(entries.first { $0.state == .active }?.version, "8.2")
    }

    func testEntriesAppendAvailableReleases() {
        let runtimes = FakeRuntimeManaging(state: RuntimeState(installed: [.php: ["8.3"]]))
        runtimes.releases = [release(.php, "7.4")]
        let vm = makeVM(runtimes: runtimes)
        let entries = vm.entries(.php)
        XCTAssertEqual(entries.map(\.version), ["8.3", "7.4"])
        XCTAssertEqual(entries.last?.state, .available)
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
        for _ in 0 ..< 50 where vm.entries(.php).isEmpty { await Task.yield() }
        XCTAssertEqual(vm.entries(.php).map(\.version), ["8.4"])
    }
}
