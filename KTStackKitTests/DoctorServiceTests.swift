import KTPlatformContracts
import KTStackCore
import XCTest
@testable import KTStackKit

final class DoctorServiceTests: XCTestCase {
    private let tld = "test"
    private lazy var paths = AppSupportPaths(root: URL(fileURLWithPath: "/tmp/ktstack-doctor-tests"))

    /// Máy khỏe hoàn toàn; mỗi test chỉ chỉnh đúng probe mình quan tâm.
    private func healthyProbes() -> DoctorProbes {
        let present = Set(
            [paths.caRootCert.path, paths.certsDir.path]
                + BinaryStager.binBinaries.map { paths.binary($0).path }
                + [
                    paths.phpFpmBinary(version: BundledPHP.defaultVersion).path,
                    paths.phpFpmSocket(BundledPHP.defaultVersion).path,
                ]
        )
        let resolverPath = DNSConstants.resolverPath(for: tld)
        return DoctorProbes(
            helperState: { DoctorHelperState(registration: .enabled, version: HelperIdentity.bundleVersion) },
            fileExists: { present.contains($0.path) },
            readFile: { $0.path == resolverPath ? DNSConstants.resolverContents : nil },
            resolveHost: { $0 == "probe.test" ? ["127.0.0.1"] : [] },
            isCATrusted: { _ in true },
            portState: { _ in .free },
            udp53Conflict: { nil },
            verifySignature: { _ in true },
            launchdSummary: { _ in "state = running; pid = 1; last exit code = 0" }
        )
    }

    func testHelperNotRegisteredFailsWithLoginItemsRemedy() {
        let check = DoctorChecks.helper(DoctorHelperState(registration: .notRegistered))
        XCTAssertEqual(check.status, .fail)
        XCTAssertEqual(check.action, .openLoginItems)
    }

    func testHelperRequiresApprovalFails() {
        let check = DoctorChecks.helper(DoctorHelperState(registration: .requiresApproval))
        XCTAssertEqual(check.status, .fail)
        XCTAssertEqual(check.action, .openLoginItems)
    }

    func testHelperWithoutSigningIdentityWarnsInsteadOfFailing() {
        let check = DoctorChecks.helper(DoctorHelperState(registration: .notApplicable))
        XCTAssertEqual(check.status, .warn, "local build without Developer ID is expected, not broken")
        XCTAssertNil(check.action)
    }

    func testHelperSilentOnXPCFails() {
        let state = DoctorHelperState(registration: .enabled, error: "Helper did not answer within 3s.")
        let check = DoctorChecks.helper(state)
        XCTAssertEqual(check.status, .fail)
        XCTAssertTrue(check.detail.contains("did not answer"))
    }

    func testStaleRegisteredHelperWarns() {
        let state = DoctorHelperState(registration: .enabled, version: "0.0.1")
        let check = DoctorChecks.helper(state)
        XCTAssertEqual(check.status, .warn)
        XCTAssertTrue(check.detail.contains("0.0.1"))
        XCTAssertTrue(check.detail.contains(HelperIdentity.bundleVersion))
    }

    func testHelperShippedWithThisBuildPasses() {
        let state = DoctorHelperState(registration: .enabled, version: HelperIdentity.bundleVersion)
        XCTAssertEqual(
            DoctorChecks.helper(state).status, .pass,
            "the helper version the app ships must not warn; it is compared against the shared constant"
        )
    }

    func testDNSResolverFileMissingFails() {
        var probes = healthyProbes()
        probes.readFile = { _ in nil }
        let check = DoctorChecks.dns(tld: tld, probes: probes)
        XCTAssertEqual(check.status, .fail)
        XCTAssertEqual(check.action, .openServices)
        XCTAssertTrue(check.detail.contains("/etc/resolver/test"))
    }

    func testDNSResolverPointingElsewhereFails() {
        var probes = healthyProbes()
        probes.readFile = { _ in "nameserver 8.8.8.8\n" }
        XCTAssertEqual(DoctorChecks.dns(tld: tld, probes: probes).status, .fail)
    }

    func testDNSResolverOnAnotherPortFails() {
        var probes = healthyProbes()
        probes.readFile = { _ in "nameserver 127.0.0.1\nport 5353\n" }
        XCTAssertEqual(
            DoctorChecks.dns(tld: tld, probes: probes).status, .fail,
            "port 5353 must not satisfy the port 53 requirement"
        )
    }

    func testDNSResolverPresentButHostDoesNotResolveFails() {
        var probes = healthyProbes()
        probes.resolveHost = { _ in [] }
        let check = DoctorChecks.dns(tld: tld, probes: probes)
        XCTAssertEqual(check.status, .fail)
        XCTAssertTrue(check.detail.contains("resolves to nothing"))
    }

    func testDNSHealthyPasses() {
        XCTAssertEqual(DoctorChecks.dns(tld: tld, probes: healthyProbes()).status, .pass)
    }

    func testTLSMissingCAFails() {
        var probes = healthyProbes()
        probes.fileExists = { _ in false }
        let check = DoctorChecks.tls(tld: tld, paths: paths, probes: probes)
        XCTAssertEqual(check.status, .fail)
        XCTAssertEqual(check.action, .openSettings)
    }

    func testTLSUntrustedCAFails() {
        var probes = healthyProbes()
        probes.isCATrusted = { _ in false }
        let check = DoctorChecks.tls(tld: tld, paths: paths, probes: probes)
        XCTAssertEqual(check.status, .fail)
        XCTAssertTrue(check.detail.contains("not trusted"))
    }

    func testTLSMissingCertsDirWarnsWithRedactedPath() {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let paths = AppSupportPaths(root: home.appendingPathComponent("Library/Application Support/KTStack"))
        let caCert = paths.caRootCert.path
        var probes = healthyProbes()
        probes.fileExists = { $0.path == caCert }
        let check = DoctorChecks.tls(tld: tld, paths: paths, probes: probes)

        XCTAssertEqual(check.status, .warn)
        XCTAssertTrue(check.detail.contains("~/Library/Application Support/KTStack"))
        XCTAssertFalse(check.detail.contains(home.path), "the user's home path must not reach the UI")
    }

    func testTLSHealthyPasses() {
        XCTAssertEqual(DoctorChecks.tls(tld: tld, paths: paths, probes: healthyProbes()).status, .pass)
    }

    func testPortsHeldByForeignProcessFailsAndKeepsItsRemedy() {
        var probes = healthyProbes()
        probes.portState = {
            $0 == 80 ? .inUse(owner: "httpd", message: "Apache (macOS built-in) is using port 80.") : .free
        }
        let check = DoctorChecks.ports(probes: probes)
        XCTAssertEqual(check.status, .fail)
        XCTAssertTrue(check.detail.contains("httpd"))
        XCTAssertEqual(check.remedy, "Apache (macOS built-in) is using port 80.")
    }

    func testPortsHeldByOurNginxPasses() {
        var probes = healthyProbes()
        probes.portState = { _ in .inUse(owner: "nginx", message: "in use") }
        XCTAssertEqual(DoctorChecks.ports(probes: probes).status, .pass)
    }

    func testUnprobeablePortWarnsWithoutClaimingAnOwner() {
        var probes = healthyProbes()
        probes.portState = { $0 == 443 ? .unavailable(message: "Could not create a probe socket.") : .free }
        let check = DoctorChecks.ports(probes: probes)
        XCTAssertEqual(check.status, .warn)
        XCTAssertTrue(check.detail.contains(":443 could not be probed"))
    }

    func testForeignDNSOnPort53FailsWithItsRemedy() {
        var probes = healthyProbes()
        probes.udp53Conflict = {
            DoctorDNSConflict(process: "Herd", message: "Stop Herd/Valet, then enable KTStack DNS.")
        }
        let check = DoctorChecks.ports(probes: probes)
        XCTAssertEqual(check.status, .fail)
        XCTAssertTrue(check.detail.contains("Herd"))
        XCTAssertEqual(check.remedy, "Stop Herd/Valet, then enable KTStack DNS.")
    }

    func testMissingRequiredBinaryFails() {
        var probes = healthyProbes()
        let nginx = paths.binary("nginx").path
        let base = healthyProbes().fileExists
        probes.fileExists = { $0.path != nginx && base($0) }
        let check = DoctorChecks.binaries(paths: paths, probes: probes)
        XCTAssertEqual(check.status, .fail)
        XCTAssertTrue(check.detail.contains("nginx"))
    }

    func testInvalidSignatureFails() {
        var probes = healthyProbes()
        let mkcert = paths.binary("mkcert").path
        probes.verifySignature = { $0.path != mkcert }
        let check = DoctorChecks.binaries(paths: paths, probes: probes)
        XCTAssertEqual(check.status, .fail)
        XCTAssertTrue(check.detail.contains("mkcert"))
    }

    func testBinariesCountOnlyWhatWasVerified() {
        let check = DoctorChecks.binaries(paths: paths, probes: healthyProbes())
        XCTAssertEqual(check.status, .pass, "mailpit is optional and absent in the healthy stub")
        XCTAssertTrue(
            check.detail.hasPrefix("\(BinaryStager.binBinaries.count + 1) staged binaries"),
            "3 bin binaries plus the default php-fpm; absent optional binaries are not counted"
        )
    }

    func testCrashedServiceFails() {
        var probes = healthyProbes()
        probes.launchdSummary = {
            $0 == ServiceKind.nginx.launchdLabel
                ? "state = not running; last exit code = 78"
                : "job not loaded (launchctl print rc=113)"
        }
        let check = DoctorChecks.services(paths: paths, probes: probes)
        XCTAssertEqual(check.status, .fail)
        XCTAssertTrue(check.detail.contains("78"))
    }

    func testRunningServiceWithOldExitCodePasses() {
        var probes = healthyProbes()
        probes.launchdSummary = { _ in "state = running; pid = 42; last exit code = 78" }
        XCTAssertEqual(
            DoctorChecks.services(paths: paths, probes: probes).status, .pass,
            "launchd keeps the previous exit code; a running job is not a failed start"
        )
    }

    func testCrashedPHPPoolIsSeen() {
        var probes = healthyProbes()
        let poolLabel = DoctorChecks.phpPoolLabel(BundledPHP.defaultVersion)
        probes.launchdSummary = {
            $0 == poolLabel
                ? "state = not running; last exit code = 70"
                : "job not loaded (launchctl print rc=113)"
        }
        let check = DoctorChecks.services(paths: paths, probes: probes)
        XCTAssertEqual(
            check.status, .fail,
            "PHP-FPM runs one job per pool version, not under com.ktstack.phpFpm"
        )
        XCTAssertTrue(check.detail.contains("PHP-FPM \(BundledPHP.defaultVersion)"))
    }

    func testNoLoadedServicesWarns() {
        var probes = healthyProbes()
        probes.launchdSummary = { _ in "job not loaded (launchctl print rc=113)" }
        XCTAssertEqual(DoctorChecks.services(paths: paths, probes: probes).status, .warn)
    }

    func testLoadedServicesPass() {
        XCTAssertEqual(DoctorChecks.services(paths: paths, probes: healthyProbes()).status, .pass)
    }

    func testMissingDefaultPHPFails() {
        var probes = healthyProbes()
        probes.fileExists = { _ in false }
        let check = DoctorChecks.php(paths: paths, probes: probes)
        XCTAssertEqual(check.status, .fail)
        XCTAssertEqual(check.action, .openRuntimes)
    }

    func testRunningPoolWithoutSocketFails() {
        var probes = healthyProbes()
        let socket = paths.phpFpmSocket(BundledPHP.defaultVersion).path
        let base = healthyProbes().fileExists
        probes.fileExists = { $0.path != socket && base($0) }
        let check = DoctorChecks.php(paths: paths, probes: probes)
        XCTAssertEqual(check.status, .fail)
        XCTAssertEqual(check.action, .openServices)
    }

    func testStoppedStackDoesNotReportAMissingSocket() {
        var probes = healthyProbes()
        probes.launchdSummary = { _ in "job not loaded (launchctl print rc=113)" }
        XCTAssertEqual(
            DoctorChecks.php(paths: paths, probes: probes).status, .pass,
            "stop() deletes the socket, so an absent socket with no job loaded is not a fault"
        )
    }

    func testPHPHealthyPasses() {
        XCTAssertEqual(DoctorChecks.php(paths: paths, probes: healthyProbes()).status, .pass)
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

    func testWorstStatusPicksTheMostSevere() {
        XCTAssertEqual(DoctorStatus.worst([]), .pass)
        XCTAssertEqual(DoctorStatus.worst([.pass, .pass]), .pass)
        XCTAssertEqual(DoctorStatus.worst([.pass, .warn]), .warn)
        XCTAssertEqual(DoctorStatus.worst([.warn, .fail, .pass]), .fail)
    }

    func testRunProducesEveryCheckAndWorstStatus() async {
        var probes = healthyProbes()
        probes.udp53Conflict = { DoctorDNSConflict(process: "Valet", message: "Stop Valet.") }
        let service = DoctorService(paths: paths, tld: tld, probes: probes, now: { Date(timeIntervalSince1970: 0) })
        let report = await service.run(environment: Self.environment)

        XCTAssertEqual(report.checks.map(\.id), ["helper", "dns", "tls", "ports", "binaries", "services", "php"])
        XCTAssertEqual(report.status, .fail, "worst check decides the overall status")
        XCTAssertEqual(report.failures.map(\.id), ["ports"])
        XCTAssertEqual(report.generatedAt, Date(timeIntervalSince1970: 0))
    }

    func testHealthyRunPasses() async {
        let service = DoctorService(paths: paths, tld: tld, probes: healthyProbes())
        let report = await service.run(environment: Self.environment)
        XCTAssertEqual(report.status, .pass)
        XCTAssertTrue(report.failures.isEmpty)
    }

    func testReportTextCarriesEveryCheckAndEnvironment() async {
        let service = DoctorService(paths: paths, tld: tld, probes: healthyProbes())
        let report = await service.run(environment: Self.environment)
        let text = DoctorReportFormatter(homePath: "/Users/tester").text(for: report)

        XCTAssertTrue(text.hasPrefix("KTStack Doctor report"))
        XCTAssertTrue(text.contains("App: 1.0 (42)"))
        XCTAssertTrue(text.contains("macOS: 14.5, arch: arm64, TLD: .test"))
        XCTAssertTrue(text.contains("Overall: PASS"))
        for check in report.checks {
            XCTAssertTrue(text.contains("[PASS] \(check.title)"), "missing \(check.title)")
        }
    }

    func testReportTextRedactsHomeDirectory() async {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let paths = AppSupportPaths(root: home.appendingPathComponent("Library/Application Support/KTStack"))
        let caCert = paths.caRootCert.path
        var probes = healthyProbes()
        probes.fileExists = { $0.path == caCert }
        let report = await DoctorService(paths: paths, tld: tld, probes: probes).run(environment: Self.environment)
        let text = DoctorReportFormatter(homePath: home.path).text(for: report)

        XCTAssertFalse(text.contains(home.path), "report must not leak the user's home path")
        XCTAssertTrue(text.contains("~/Library/Application Support/KTStack"))
    }

    func testReportTextCarriesNoLogContent() async {
        let service = DoctorService(paths: paths, tld: tld, probes: healthyProbes())
        let report = await service.run(environment: Self.environment)
        let text = DoctorReportFormatter(homePath: "/Users/tester").text(for: report)

        XCTAssertFalse(
            text.contains(".log"),
            "log tails carry DSNs and request URIs; the report is pasted into public issues"
        )
    }

    func testReportTextIncludesRemedyForFailingCheck() async {
        var probes = healthyProbes()
        probes.readFile = { _ in nil }
        let service = DoctorService(paths: paths, tld: tld, probes: probes)
        let report = await service.run(environment: Self.environment)
        let text = DoctorReportFormatter(homePath: "/Users/tester").text(for: report)

        XCTAssertTrue(text.contains("[FAIL] DNS"))
        XCTAssertTrue(text.contains("Fix: Enable DNS on the Services screen."))
        XCTAssertTrue(text.contains("Overall: FAIL"))
    }

    private static let environment = DoctorEnvironment(
        appVersion: "1.0", appBuild: "42", systemVersion: "14.5", architecture: "arm64", tld: "test"
    )
}
