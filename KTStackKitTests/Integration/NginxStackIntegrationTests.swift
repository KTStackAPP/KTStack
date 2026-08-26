import XCTest
@testable import KTStackKit

/// Real-stack checks for the front nginx: generated configs pass nginx -t, the front binds its
/// ports, and static sites answer over HTTP and HTTPS with a harness-minted mkcert CA.
final class NginxStackIntegrationTests: XCTestCase {
    private var harness: IntegrationStackHarness!
    private var upstream: LoopbackUpstream!
    private let plainDomain = "ktstack-it-plain.test"
    private let secureDomain = "ktstack-it-secure.test"
    private let proxyDomain = "ktstack-it-proxy.test"

    override func setUpWithError() throws {
        try IntegrationStackHarness.requireEnabled()
        harness = try IntegrationStackHarness()
        upstream = try LoopbackUpstream()
        let plainRoot = try harness.makeDocroot("plain", files: ["index.html": "plain-ok"])
        let secureRoot = try harness.makeDocroot("secure", files: ["index.html": "secure-ok"])
        try harness.mintCert(domain: secureDomain)
        try harness.generateConfigs(sites: [
            Site(
                name: "plain", path: plainRoot.path, docroot: plainRoot.path,
                domain: plainDomain, phpVersion: "8.4", type: .staticSite
            ),
            Site(
                name: "secure", path: secureRoot.path, docroot: secureRoot.path,
                domain: secureDomain, phpVersion: "8.4", type: .staticSite, secure: true
            ),
            Site(
                name: "proxy", path: "", docroot: "",
                domain: proxyDomain, phpVersion: "8.4", type: .proxy,
                proxyTarget: "http://127.0.0.1:\(upstream.port)"
            ),
        ])
    }

    override func tearDown() {
        upstream?.stop()
        upstream = nil
        harness?.teardown()
        harness = nil
        super.tearDown()
    }

    func testGeneratedFrontConfigPassesNginxT() throws {
        try harness.nginxT(conf: harness.paths.nginxConf)
    }

    func testFrontBindsPortsAndServesStaticSites() throws {
        try harness.startNginx(conf: harness.paths.nginxConf)
        try harness.waitForPort(harness.httpPort)
        try harness.waitForPort(harness.httpsPort)

        let plain = try harness.request(scheme: "http", domain: plainDomain, port: harness.httpPort)
        XCTAssertEqual(plain.status, 200)
        XCTAssertEqual(plain.body, "plain-ok")

        let secure = try harness.request(
            scheme: "https", domain: secureDomain, port: harness.httpsPort, verifyWithLocalCA: true
        )
        XCTAssertEqual(secure.status, 200)
        XCTAssertEqual(secure.body, "secure-ok")

        let redirect = try harness.request(scheme: "http", domain: secureDomain, port: harness.httpPort)
        XCTAssertEqual(redirect.status, 301)
        XCTAssertEqual(redirect.header("location"), "https://\(secureDomain)/")
    }

    func testProxySiteRoutesToLoopbackUpstream() throws {
        try harness.startNginx(conf: harness.paths.nginxConf)
        try harness.waitForPort(harness.httpPort)

        let reply = try harness.request(scheme: "http", domain: proxyDomain, port: harness.httpPort)
        XCTAssertEqual(reply.status, 200)
        XCTAssertTrue(reply.body.contains("upstream-ok"), reply.body)
        XCTAssertTrue(reply.body.contains("proto=http"), reply.body)
    }
}
