import KTPlatformContracts
import KTStackCore
import XCTest
@testable import KTStackKit

final class DoctorProbeServiceTests: XCTestCase {
    private var root: URL!
    private var paths: AppSupportPaths!

    override func setUpWithError() throws {
        root = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("ktstack-probe-tests-\(UUID().uuidString)")
        paths = AppSupportPaths(root: root)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: root)
    }

    private func installPHP(_ version: String) throws {
        let binary = paths.phpFpmBinary(version: version)
        try FileManager.default.createDirectory(
            at: binary.deletingLastPathComponent(), withIntermediateDirectories: true
        )
        try Data().write(to: binary)
    }

    func testInstalledPHPVersionsReflectStagedBinaries() throws {
        try installPHP("8.4")
        let service = DoctorProbeService(paths: paths)
        XCTAssertEqual(service.installedPHPVersions, ["8.4"])
        XCTAssertEqual(service.defaultPHPVersion, BundledPHP.defaultVersion)
    }

    func testInstalledPHP85IsProbedAndGetsAPoolJob() throws {
        try installPHP("8.5")
        let service = DoctorProbeService(paths: paths)
        XCTAssertEqual(service.installedPHPVersions, ["8.5"])
        XCTAssertTrue(service.launchdJobs.map(\.label).contains(service.phpPoolLabel("8.5")))
    }

    func testStagedBinariesListRequiredOptionalThenInstalledPHP() throws {
        try installPHP("8.4")
        let service = DoctorProbeService(paths: paths)
        let names = service.stagedBinaries.map(\.name)
        XCTAssertEqual(names, BinaryStager.binBinaries + BinaryStager.optionalBinaryNames + ["php-fpm 8.4"])

        let required = Dictionary(uniqueKeysWithValues: service.stagedBinaries.map { ($0.name, $0.required) })
        XCTAssertEqual(required["nginx"], true)
        XCTAssertEqual(required["mailpit"], false)
        XCTAssertEqual(required["php-fpm 8.4"], false)
    }

    func testLaunchdJobsDropPhpFpmAndDnsmasqAndAddPoolPerVersion() throws {
        try installPHP("8.4")
        let service = DoctorProbeService(paths: paths)
        let labels = service.launchdJobs.map(\.label)

        XCTAssertFalse(labels.contains(ServiceKind.phpFpm.launchdLabel), "phpFpm job is per pool, not the bare kind")
        XCTAssertFalse(labels.contains(ServiceKind.dnsmasq.launchdLabel), "dnsmasq is a root daemon, not user-domain")
        XCTAssertTrue(labels.contains(ServiceKind.nginx.launchdLabel))
        XCTAssertTrue(labels.contains(service.phpPoolLabel("8.4")))
    }

    func testPhpPoolLabelIsVersionSuffixedKind() {
        let service = DoctorProbeService(paths: paths)
        XCTAssertEqual(service.phpPoolLabel("8.4"), "\(ServiceKind.phpFpm.launchdLabel).8.4")
    }

    func testLaunchdJobStateReadsUnloadedRunningAndCrashed() {
        XCTAssertNil(LaunchdJobState(summary: "job not loaded (launchctl print rc=113)"))

        let noInfo = LaunchdJobState(summary: "job loaded, no exit info reported")
        XCTAssertEqual(noInfo?.isRunning, false)
        XCTAssertNil(noInfo?.lastExitCode)
        XCTAssertEqual(noInfo?.failedStart, false, "no exit code reported is not a failed start")

        let crashed = LaunchdJobState(summary: "state = not running; last exit code = 2; last exit reason = signal")
        XCTAssertEqual(crashed?.lastExitCode, 2)
        XCTAssertEqual(crashed?.failedStart, true)

        let running = LaunchdJobState(summary: "state = running; pid = 7; last exit code = 2")
        XCTAssertEqual(running?.isRunning, true)
        XCTAssertEqual(running?.failedStart, false)
    }
}
