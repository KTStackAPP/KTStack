import XCTest
@testable import KTStackKit

/// Real-stack checks for a PHP site: front proxy + loopback backend, the directory-redirect
/// regression, and (when a PHP runtime is installed) an actual page served through php-fpm.
final class PHPSiteServingIntegrationTests: XCTestCase {
    private var harness: IntegrationStackHarness!
    private var site: Site!
    private var backendPort = 0
    private let domain = "ktstack-it-php.test"
    private let phpVersion = IntegrationStackHarness.installedRealPHPVersion() ?? "8.4"

    override func setUpWithError() throws {
        try IntegrationStackHarness.requireEnabled()
        harness = try IntegrationStackHarness()
        backendPort = try IntegrationStackHarness.probeFreePort()
        let docroot = try harness.makeDocroot("phpsite", files: [
            "index.php": "<?php echo 'ktstack-php-fpm-ok';",
            "assets/style.css": "/* ktstack */",
        ])
        site = Site(
            name: "phpsite", path: docroot.path, docroot: docroot.path,
            domain: domain, phpVersion: phpVersion, type: .php, backendPort: backendPort
        )
        try harness.generateConfigs(sites: [site])
    }

    override func tearDown() {
        harness?.teardown()
        harness = nil
        super.tearDown()
    }

    func testGeneratedBackendConfigPassesNginxT() throws {
        try harness.nginxT(conf: harness.paths.siteBackendConf(site.id.uuidString))
    }

    /// Directory redirect must keep the public origin: a relative Location, never the loopback
    /// backend port (the absolute_redirect regression).
    func testDirectoryRedirectKeepsPublicOrigin() throws {
        try startFrontAndBackend()
        let reply = try harness.request(
            scheme: "http", domain: domain, port: harness.httpPort, path: "/assets"
        )
        XCTAssertEqual(reply.status, 301)
        let location = try XCTUnwrap(reply.header("location"))
        XCTAssertEqual(location, "/assets/")
        XCTAssertFalse(location.contains("\(backendPort)"), "backend port leaked into Location: \(location)")
    }

    func testPHPPageServesThroughFPM() throws {
        guard IntegrationStackHarness.installedRealPHPVersion() != nil else {
            throw XCTSkip(
                "no PHP runtime under ~/Library/Application Support/KTStack/runtimes/php; install one in KTStack to enable this case"
            )
        }
        try harness.linkRealPHPRuntime(version: phpVersion)
        try harness.startPHPFPM(version: phpVersion)
        try startFrontAndBackend()
        let reply = try harness.request(scheme: "http", domain: domain, port: harness.httpPort)
        XCTAssertEqual(reply.status, 200)
        XCTAssertEqual(reply.body, "ktstack-php-fpm-ok")
    }

    func testEnvVarReachesPHPViaFastCGI() throws {
        guard IntegrationStackHarness.installedRealPHPVersion() != nil else {
            throw XCTSkip("no PHP runtime installed; env-var-through-fastcgi case needs a real php-fpm")
        }
        let docroot = try harness.makeDocroot("phpenv", files: [
            "index.php": "<?php echo 'APP_DEBUG=' . getenv('APP_DEBUG');",
        ])
        let envSite = Site(
            name: "phpenv", path: docroot.path, docroot: docroot.path,
            domain: domain, phpVersion: phpVersion, type: .php, backendPort: backendPort,
            envVars: ["APP_DEBUG": "1"]
        )
        try harness.generateConfigs(sites: [envSite])
        try harness.linkRealPHPRuntime(version: phpVersion)
        try harness.startPHPFPM(version: phpVersion)
        try harness.startNginx(conf: harness.paths.siteBackendConf(envSite.id.uuidString))
        try harness.waitForPort(backendPort, logTailFrom: harness.paths.siteErrorLog(domain))
        try harness.startNginx(conf: harness.paths.nginxConf)
        try harness.waitForPort(harness.httpPort)

        let reply = try harness.request(scheme: "http", domain: domain, port: harness.httpPort)
        XCTAssertEqual(reply.status, 200)
        XCTAssertEqual(reply.body, "APP_DEBUG=1")
    }

    private func startFrontAndBackend() throws {
        try harness.startNginx(conf: harness.paths.siteBackendConf(site.id.uuidString))
        try harness.waitForPort(backendPort, logTailFrom: harness.paths.siteErrorLog(domain))
        try harness.startNginx(conf: harness.paths.nginxConf)
        try harness.waitForPort(harness.httpPort)
    }
}
