import KTPlatformContracts
import KTStackCore
import XCTest
@testable import KTStackKit

@MainActor
final class SiteWildcardSubdomainsTests: XCTestCase {
    private let fm = FileManager.default

    private func makePaths() throws -> (AppSupportPaths, URL) {
        let root = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("kd-wildcard-\(UUID().uuidString)", isDirectory: true)
        let paths = AppSupportPaths(root: root)
        try paths.ensureDirectoryTree()
        return (paths, root)
    }

    private func site(
        _ domain: String = "shop.test",
        type: SiteType = .php,
        secure: Bool = false,
        aliases: [String] = [],
        wildcard: Bool = true
    ) -> Site {
        Site(
            name: "shop", path: "/tmp/shop", docroot: "/tmp/shop/public", domain: domain,
            phpVersion: BundledPHP.defaultVersion, type: type, secure: secure, backendPort: 4001,
            aliases: aliases, wildcardSubdomains: wildcard
        )
    }

    private func writeCert(_ domain: String, _ paths: AppSupportPaths) throws {
        try fm.createDirectory(at: paths.siteCertDir(domain), withIntermediateDirectories: true)
        try Data().write(to: paths.siteCert(domain))
        try Data().write(to: paths.siteKey(domain))
    }

    // MARK: - Model

    func testOldSitesJSONDecodesWithWildcardOff() throws {
        let json = """
        {"name":"shop","path":"/s","docroot":"/s","domain":"shop.test","phpVersion":"8.4","type":"php"}
        """
        let decoded = try JSONDecoder().decode(Site.self, from: Data(json.utf8))
        XCTAssertFalse(decoded.wildcardSubdomains)
        XCTAssertNil(decoded.wildcardName)
        XCTAssertEqual(decoded.serverNames, ["shop.test"])
    }

    func testWildcardRoundTripsThroughJSON() throws {
        let data = try JSONEncoder().encode(site())
        XCTAssertTrue(try JSONDecoder().decode(Site.self, from: data).wildcardSubdomains)
    }

    func testRoutedAliasesAppendWildcardAfterAliases() {
        let s = site(aliases: ["www.shop.test"])
        XCTAssertEqual(s.wildcardName, "*.shop.test")
        XCTAssertEqual(s.routedAliases, ["www.shop.test", "*.shop.test"])
        XCTAssertEqual(s.serverNames, ["shop.test", "www.shop.test", "*.shop.test"])
        XCTAssertEqual(s.aliases, ["www.shop.test"], "the wildcard never lands in the stored aliases")
    }

    // MARK: - Front + backend config

    func testPHPFrontVhostCarriesWildcardServerName() throws {
        let (paths, root) = try makePaths(); defer { try? fm.removeItem(at: root) }
        let vhost = SiteConfigGenerator(paths: paths).frontVhostText(for: site(aliases: ["www.shop.test"]))
        XCTAssertTrue(vhost.contains("server_name shop.test www.shop.test *.shop.test;"))
    }

    func testWildcardOffLeavesServerNameUnchanged() throws {
        let (paths, root) = try makePaths(); defer { try? fm.removeItem(at: root) }
        let vhost = SiteConfigGenerator(paths: paths).frontVhostText(for: site(wildcard: false))
        XCTAssertTrue(vhost.contains("server_name shop.test;"))
        XCTAssertFalse(vhost.contains("*."))
    }

    func testSecureStaticVhostCarriesWildcardOnRedirectAndTLSBlocks() throws {
        let (paths, root) = try makePaths(); defer { try? fm.removeItem(at: root) }
        try writeCert("shop.test", paths)
        let vhost = SiteConfigGenerator(paths: paths).frontVhostText(for: site(type: .staticSite, secure: true))
        let names = vhost.components(separatedBy: "server_name shop.test *.shop.test;").count - 1
        XCTAssertEqual(names, 2, "both the :80 redirect and the :443 server answer the wildcard")
        XCTAssertTrue(vhost.contains("listen 0.0.0.0:443 ssl;"))
    }

    func testNginxBackendCarriesWildcardServerName() throws {
        let (paths, root) = try makePaths(); defer { try? fm.removeItem(at: root) }
        let conf = SiteConfigGenerator(paths: paths).backendConfigText(for: site(), backendPort: 4001)
        XCTAssertTrue(conf.contains("server_name shop.test *.shop.test;"))
    }

    func testApacheBackendCarriesWildcardServerAliasAndKeepsRequestHost() {
        let paths = AppSupportPaths(root: URL(fileURLWithPath: "/tmp/ktstack-test"))
        let conf = ApacheBackend(serverRoot: paths.apacheRoot).backendConfig(context: BackendRenderContext(
            domain: "shop.test",
            root: URL(fileURLWithPath: "/s/public"),
            phpFpmSocket: paths.phpFpmSocket("8.4"),
            backendPort: 4001,
            secure: true,
            pidFile: paths.siteBackendPid("ID", engine: "apache"),
            accessLog: paths.siteAccessLog("shop.test"),
            errorLog: paths.siteErrorLog("shop.test"),
            aliases: site().routedAliases
        ))
        XCTAssertTrue(conf.contains("ServerAlias *.shop.test"))
        // Self-referential redirects keep tenant.shop.test instead of jumping to shop.test.
        XCTAssertTrue(conf.contains("UseCanonicalName Off"))
        XCTAssertTrue(conf.contains("ServerName shop.test:443"))
    }

    // MARK: - Certificate

    func testProvisionerMintsWildcardSAN() throws {
        var minted: [String] = []
        let provisioner = SiteHTTPSProvisioner(
            caCert: URL(fileURLWithPath: "/tmp/rootCA.pem"),
            tld: "test",
            trustQuery: { _ in true },
            installCA: {},
            mintLeaf: { domain, aliases, _ in minted = [domain] + aliases }
        )
        try provisioner.enableHTTPS(for: site(aliases: ["www.shop.test"]))
        XCTAssertEqual(minted, ["shop.test", "www.shop.test", "*.shop.test"])
    }

    func testMintArgsCarryWildcardSAN() {
        let args = MkcertRunner.mintArgs(
            domain: "shop.test",
            aliases: site().routedAliases,
            certFile: URL(fileURLWithPath: "/c/cert.pem"),
            keyFile: URL(fileURLWithPath: "/c/key.pem")
        )
        XCTAssertEqual(args.suffix(2), ["shop.test", "*.shop.test"])
    }

    func testMintRejectsTLDWideWildcard() {
        let p = AppSupportPaths(root: URL(fileURLWithPath: "/tmp/kd-x"))
        let minter = CertMinter(paths: p, runner: MkcertRunner(mkcert: p.mkcertBinary, caroot: p.caDir))
        XCTAssertThrowsError(try minter.mint(name: "shop", domain: "shop.test", aliases: ["*.test"])) { error in
            guard let certError = error as? CertMinter.CertError,
                  case .wildcardTooBroad("*.test") = certError else {
                return XCTFail("expected wildcardTooBroad, got \(error)")
            }
        }
    }

    func testMintRejectsWildcardOutsideTLD() {
        let p = AppSupportPaths(root: URL(fileURLWithPath: "/tmp/kd-x"))
        let minter = CertMinter(paths: p, runner: MkcertRunner(mkcert: p.mkcertBinary, caroot: p.caDir))
        XCTAssertThrowsError(try minter.mint(name: "shop", domain: "shop.test", aliases: ["*.evil.com"])) { error in
            XCTAssertTrue("\(error)".contains("*.evil.com"))
        }
    }

    // MARK: - Registry, catalog, IPC

    private func makeServer() throws -> (LocalServerController, AppSupportPaths, URL) {
        let (paths, root) = try makePaths()
        let server = LocalServerController(bundleBinDir: URL(fileURLWithPath: "/dev/null"), paths: paths)
        let folder = paths.config.appendingPathComponent("scratch/shop", isDirectory: true)
        try fm.createDirectory(at: folder, withIntermediateDirectories: true)
        try "<?php".write(to: folder.appendingPathComponent("index.php"), atomically: true, encoding: .utf8)
        try server.registry.add(folder: folder)
        return (server, paths, root)
    }

    func testCatalogToggleOnInsecureSitePersistsAndProjects() throws {
        let (server, _, root) = try makeServer(); defer { try? fm.removeItem(at: root) }
        let id = try XCTUnwrap(server.registry.sites.first?.id)

        try (server as any SiteCatalogManaging).setWildcardSubdomains(id, true)
        XCTAssertEqual(server.registry.sites.first?.wildcardSubdomains, true)
        XCTAssertEqual(server.catalog.sites.first?.wildcardSubdomains, true)

        try (server as any SiteCatalogManaging).setWildcardSubdomains(id, false)
        XCTAssertEqual(server.registry.sites.first?.wildcardSubdomains, false)
    }

    func testWildcardFollowsTLDMigration() throws {
        let (server, _, root) = try makeServer(); defer { try? fm.removeItem(at: root) }
        let s = try XCTUnwrap(server.registry.sites.first)
        server.registry.setWildcardSubdomains(s, true)
        let migrated = server.registry.migrateTLD(from: "test", to: "dev")
        let domain = try XCTUnwrap(migrated.first?.domain)
        XCTAssertTrue(domain.hasSuffix(".dev"))
        XCTAssertEqual(migrated.first?.wildcardName, "*.\(domain)")
        XCTAssertEqual(migrated.first?.aliases, [], "the wildcard is derived, never rewritten into aliases")
    }

    func testIPCSitesListReportsWildcardFlag() async throws {
        let (server, _, root) = try makeServer(); defer { try? fm.removeItem(at: root) }
        let s = try XCTUnwrap(server.registry.sites.first)
        server.registry.setWildcardSubdomains(s, true)

        let dispatcher = KTIPCCommandDispatcher(serverProvider: { server }, servicesProvider: { nil })
        let response = await dispatcher.dispatch(KTIPCRequest(id: "1", method: "sites.list"))
        let raw = try XCTUnwrap(response.result)
        let list = try JSONDecoder().decode([KTIPCSiteInfo].self, from: Data(raw.utf8))
        XCTAssertEqual(list.first?.wildcardSubdomains, true)
    }

    func testIPCSiteInfoFromOlderAppDecodesWildcardOff() throws {
        let json = """
        [{"id":"1","name":"shop","domain":"shop.test","path":"/s","phpVersion":"8.4","secure":true,"backendPort":4001}]
        """
        let list = try JSONDecoder().decode([KTIPCSiteInfo].self, from: Data(json.utf8))
        XCTAssertEqual(list.first?.wildcardSubdomains, false)
    }
}
