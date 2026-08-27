import XCTest
@testable import KTStackKit

/// Real-stack checks for the front nginx: generated configs pass nginx -t, the front binds its
/// ports, and static sites answer over HTTP and HTTPS with a harness-minted mkcert CA.
final class NginxStackIntegrationTests: XCTestCase {
    private var harness: IntegrationStackHarness!
    private var upstream: LoopbackUpstream!
    private var sites: [Site] = []
    private var plainID = UUID()
    private let plainDomain = "ktstack-it-plain.test"
    private let aliasDomain = "ktstack-it-alias.test"
    private let secureDomain = "ktstack-it-secure.test"
    private let proxyDomain = "ktstack-it-proxy.test"

    override func setUpWithError() throws {
        try IntegrationStackHarness.requireEnabled()
        harness = try IntegrationStackHarness()
        upstream = try LoopbackUpstream()
        let plainRoot = try harness.makeDocroot("plain", files: ["index.html": "plain-ok"])
        let secureRoot = try harness.makeDocroot("secure", files: ["index.html": "secure-ok"])
        try harness.mintCert(domain: secureDomain)
        let plain = Site(
            name: "plain", path: plainRoot.path, docroot: plainRoot.path,
            domain: plainDomain, phpVersion: "8.4", type: .staticSite, aliases: [aliasDomain]
        )
        plainID = plain.id
        sites = [
            plain,
            Site(
                name: "secure", path: secureRoot.path, docroot: secureRoot.path,
                domain: secureDomain, phpVersion: "8.4", type: .staticSite, secure: true
            ),
            Site(
                name: "proxy", path: "", docroot: "",
                domain: proxyDomain, phpVersion: "8.4", type: .proxy,
                proxyTarget: "http://127.0.0.1:\(upstream.port)"
            ),
        ]
        try harness.generateConfigs(sites: sites)
    }

    private func withPlain(_ mutate: (inout Site) -> Void) -> [Site] {
        sites.map { site in
            guard site.id == plainID else { return site }
            var copy = site
            mutate(&copy)
            return copy
        }
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

    func testAliasServedByFrontVhost() throws {
        try harness.startNginx(conf: harness.paths.nginxConf)
        try harness.waitForPort(harness.httpPort)

        let reply = try harness.request(scheme: "http", domain: aliasDomain, port: harness.httpPort)
        XCTAssertEqual(reply.status, 200)
        XCTAssertEqual(reply.body, "plain-ok")
    }

    func testFrontDirectivesAddHeaderThenCleanup() throws {
        let withDirectives = withPlain { $0.frontDirectives = "add_header X-KT-Directive on;" }
        try harness.generateConfigs(sites: withDirectives)
        try harness.startNginx(conf: harness.paths.nginxConf)
        try harness.waitForPort(harness.httpPort)

        let present = try harness.request(scheme: "http", domain: plainDomain, port: harness.httpPort)
        XCTAssertEqual(present.status, 200)
        XCTAssertEqual(present.header("x-kt-directive"), "on")

        let directivesFile = harness.paths.siteDirectivesConf(plainID.uuidString)
        XCTAssertTrue(FileManager.default.fileExists(atPath: directivesFile.path))

        // Removing the directives regenerates the vhost without the include and reaps the orphan file.
        try harness.generateConfigs(sites: sites)
        XCTAssertFalse(FileManager.default.fileExists(atPath: directivesFile.path))
        let vhost = try String(contentsOf: harness.paths.vhost(plainDomain), encoding: .utf8)
        XCTAssertFalse(vhost.contains("site-directives"))
        try harness.nginxT(conf: harness.paths.nginxConf)
    }

    func testRejectedDirectivesFailNginxTAndKeepServing() throws {
        try harness.startNginx(conf: harness.paths.nginxConf)
        try harness.waitForPort(harness.httpPort)
        XCTAssertEqual(try harness.request(scheme: "http", domain: plainDomain, port: harness.httpPort).status, 200)

        // A rejected save would write these to disk then run nginx -t; prove real nginx refuses them.
        let bad = withPlain { $0.frontDirectives = "foo bar;" }
        try harness.generateConfigs(sites: bad)
        XCTAssertThrowsError(try harness.nginxT(conf: harness.paths.nginxConf))

        // Rollback regenerates the previous good config; the running front never reloaded the bad one.
        try harness.generateConfigs(sites: sites)
        try harness.nginxT(conf: harness.paths.nginxConf)
        XCTAssertEqual(try harness.request(scheme: "http", domain: plainDomain, port: harness.httpPort).status, 200)
    }
}
