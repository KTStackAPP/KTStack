import KTPlatformContracts
import KTStackCore
import XCTest
@testable import KTStackKit

final class SiteWorkerSupervisorTests: XCTestCase {
    private var root: URL!
    private var paths: AppSupportPaths!
    private var agents: FakeLaunchAgentManager!
    private let siteID = UUID()

    override func setUpWithError() throws {
        root = FileManager.default.temporaryDirectory.appendingPathComponent("kd-site-workers-\(UUID().uuidString)")
        paths = AppSupportPaths(root: root)
        try paths.ensureDirectoryTree()
        agents = FakeLaunchAgentManager(paths: paths)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: root)
    }

    private func supervisor(executable: URL? = URL(fileURLWithPath: "/App/kt")) -> SiteWorkerSupervisor {
        let agents = agents!
        return SiteWorkerSupervisor(
            paths: paths,
            agents: agents,
            listLoaded: { prefix in agents.loadedLabels.filter { $0.hasPrefix(prefix) }.sorted() },
            supervisorExecutable: { executable },
            effectivePHPVersion: { $0 },
            parentPID: 4242
        )
    }

    private func site(type: SiteType = .php, workers: [SiteWorker], env: [String: String] = [:]) -> Site {
        Site(
            id: siteID, name: "shop", path: "/Users/me/shop", docroot: "/Users/me/shop/public", domain: "shop.test",
            phpVersion: "8.4", type: type, backendPort: 4001, envVars: env, workers: workers
        )
    }

    private var bootstrapped: [String] {
        agents.calls.compactMap(Self.bootstrapLabel)
    }

    private var bootedOut: [String] {
        agents.calls.compactMap(Self.bootoutLabel)
    }

    private static func bootstrapLabel(_ call: FakeLaunchAgentManager.Call) -> String? {
        guard case let .bootstrap(label) = call else { return nil }
        return label
    }

    private static func bootoutLabel(_ call: FakeLaunchAgentManager.Call) -> String? {
        guard case let .bootout(label) = call else { return nil }
        return label
    }

    func testOnlyEnabledWorkersOfPHPSitesAreStarted() {
        let queue = SiteWorker(name: "queue", command: "php artisan queue:work", enabled: true)
        let idle = SiteWorker(name: "idle", command: "php artisan schedule:work", enabled: false)
        let shop = site(workers: [queue, idle])
        var node = site(type: .node, workers: [SiteWorker(name: "dev", command: "npm run dev", enabled: true)])
        node = Site(
            name: "app", path: "/Users/me/app", docroot: "/Users/me/app", domain: "app.test",
            phpVersion: "8.4", type: .node, workers: node.workers
        )
        supervisor().reconcile(sites: [shop, node])

        XCTAssertEqual(bootstrapped, [paths.siteWorkerLabel(siteID: shop.id.uuidString, workerID: queue.id.uuidString)])
    }

    func testSpecRunsThePHPCommandThroughTheSupervisorWithTheSiteEnvironment() throws {
        let worker = SiteWorker(name: "queue", command: "php artisan queue:work --queue='high, low'", enabled: true)
        let shop = site(workers: [worker], env: ["APP_ENV": "local"])
        let launch = SiteWorkerLaunch(paths: paths, supervisorExecutable: URL(fileURLWithPath: "/App/kt"), parentPID: 4242)
        let spec = try XCTUnwrap(launch.spec(site: shop, worker: worker, phpVersion: "8.4"))

        let label = paths.siteWorkerLabel(siteID: shop.id.uuidString, workerID: worker.id.uuidString)
        XCTAssertEqual(spec.programArguments, [
            "/App/kt", WorkerSupervisor.command, "--parent-pid", "4242",
            "--status", paths.siteWorkerStatus(label).path, "--",
            paths.phpBinary(version: "8.4").path, "artisan", "queue:work", "--queue=high, low",
        ])
        XCTAssertEqual(spec.workingDirectory, "/Users/me/shop")
        XCTAssertEqual(spec.stdoutPath, paths.siteWorkerLog("shop.test", worker: "queue").path)
        XCTAssertEqual(spec.environment["APP_ENV"], "local")
        XCTAssertEqual(spec.environment["PHPRC"], paths.phpIniDir(version: "8.4").path)
        XCTAssertTrue(spec.environment["PATH"]?.hasPrefix(paths.runtimeBin("php", "8.4").path + ":") == true)
        XCTAssertTrue(spec.keepAliveOnCrash)
    }

    func testNonPHPCommandsKeepTheirProgram() {
        let launch = SiteWorkerLaunch(paths: paths, supervisorExecutable: URL(fileURLWithPath: "/App/kt"), parentPID: 1)
        let program = launch.resolvedProgram(["vendor/bin/horizon", "--verbose"], phpVersion: "8.4")
        XCTAssertEqual(program.executable, "vendor/bin/horizon")
        XCTAssertEqual(program.arguments, ["--verbose"])
    }

    func testUnchangedSpecIsNotReloadedButAChangedOneIs() {
        let worker = SiteWorker(name: "queue", command: "php artisan queue:work", enabled: true)
        let runner = supervisor()
        runner.reconcile(sites: [site(workers: [worker])])
        runner.reconcile(sites: [site(workers: [worker])])
        XCTAssertEqual(bootstrapped.count, 1)
        XCTAssertTrue(bootedOut.isEmpty)

        runner.reconcile(sites: [site(workers: [worker], env: ["APP_ENV": "testing"])])
        XCTAssertEqual(bootstrapped.count, 2)
        XCTAssertEqual(bootedOut.count, 1)
    }

    func testDisabledOrRemovedWorkersAreTornDown() throws {
        var worker = SiteWorker(name: "queue", command: "php artisan queue:work", enabled: true)
        let shop = site(workers: [worker])
        let runner = supervisor()
        runner.reconcile(sites: [shop])
        let label = paths.siteWorkerLabel(siteID: shop.id.uuidString, workerID: worker.id.uuidString)
        XCTAssertTrue(FileManager.default.fileExists(atPath: paths.siteWorkerSpec(label).path))

        worker.enabled = false
        var stopped = shop
        stopped.workers = [worker]
        runner.reconcile(sites: [stopped])
        XCTAssertEqual(bootedOut, [label])
        XCTAssertFalse(agents.loadedLabels.contains(label))
        XCTAssertFalse(FileManager.default.fileExists(atPath: paths.siteWorkerSpec(label).path))
    }

    func testStopAllBootsOutEveryWorker() {
        let shop = site(workers: [
            SiteWorker(name: "queue", command: "php artisan queue:work", enabled: true),
            SiteWorker(name: "scheduler", command: "php artisan schedule:work", enabled: true),
        ])
        let runner = supervisor()
        runner.reconcile(sites: [shop])
        runner.stopAll()
        XCTAssertEqual(bootedOut.count, 2)
        XCTAssertTrue(agents.loadedLabels.isEmpty)
    }

    func testMissingSupervisorStartsNothing() {
        let shop = site(workers: [SiteWorker(name: "queue", command: "php artisan queue:work", enabled: true)])
        supervisor(executable: nil).reconcile(sites: [shop])
        XCTAssertTrue(bootstrapped.isEmpty)
    }

    func testStatusesFollowEnabledServerAndSupervisorState() {
        let running = SiteWorker(name: "queue", command: "php artisan queue:work", enabled: true)
        let disabled = SiteWorker(name: "idle", command: "php artisan schedule:work", enabled: false)
        let shop = site(workers: [running, disabled])
        let runner = supervisor()

        let offline = runner.statuses(sites: [shop], serverRunning: false)
        XCTAssertEqual(offline.status(of: running.id).state, .waitingForServer)
        XCTAssertEqual(offline.status(of: disabled.id).state, .stopped)

        runner.reconcile(sites: [shop])
        XCTAssertEqual(runner.statuses(sites: [shop], serverRunning: true).status(of: running.id).state, .starting)

        let label = paths.siteWorkerLabel(siteID: shop.id.uuidString, workerID: running.id.uuidString)
        WorkerStatus(state: .backoff, restarts: 2, lastExitStatus: 1).write(to: paths.siteWorkerStatus(label))
        let status = runner.statuses(sites: [shop], serverRunning: true).status(of: running.id)
        XCTAssertEqual(status.state, .backoff)
        XCTAssertEqual(status.restarts, 2)
        XCTAssertEqual(status.lastExitStatus, 1)
    }

    func testRestartKickstartsALoadedWorker() {
        let worker = SiteWorker(name: "queue", command: "php artisan queue:work", enabled: true)
        let shop = site(workers: [worker])
        let runner = supervisor()
        let label = paths.siteWorkerLabel(siteID: shop.id.uuidString, workerID: worker.id.uuidString)
        runner.restart(site: shop, worker: worker)
        XCTAssertFalse(agents.calls.contains(.kickstart(label)))
        runner.reconcile(sites: [shop])
        runner.restart(site: shop, worker: worker)
        XCTAssertTrue(agents.calls.contains(.kickstart(label)))
    }
}
