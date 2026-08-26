import KTStackCore
import XCTest
@testable import KTStackKit

final class SiteConfigGeneratorProxyTests: XCTestCase {
    private let fm = FileManager.default

    private func makePaths() -> (AppSupportPaths, URL) {
        let root = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("kd-proxy-gen-\(UUID().uuidString)", isDirectory: true)
        let paths = AppSupportPaths(root: root)
        try? paths.ensureDirectoryTree()
        return (paths, root)
    }

    private func proxySite(_ domain: String, target: String, secure: Bool = false) -> Site {
        Site(
            name: domain,
            path: "",
            docroot: "",
            domain: domain,
            phpVersion: BundledPHP.defaultVersion,
            type: .proxy,
            secure: secure,
            proxyTarget: target
        )
    }

    func testHttpProxyEmitsUpstreamPassWithHostVariable() {
        let (paths, root) = makePaths(); defer { try? fm.removeItem(at: root) }
        let gen = SiteConfigGenerator(paths: paths)
        let vhost = gen.frontVhostText(for: proxySite("app.test", target: "http://192.168.1.20:3000"))
        XCTAssertTrue(vhost.contains("proxy_pass http://192.168.1.20:3000;"))
        XCTAssertTrue(vhost.contains("proxy_set_header Host $host;"))
        XCTAssertFalse(vhost.contains("root "))
        XCTAssertFalse(vhost.contains("try_files"))
    }

    func testHttpsProxyEmitsSNIAndUpstreamHost() {
        let (paths, root) = makePaths(); defer { try? fm.removeItem(at: root) }
        let gen = SiteConfigGenerator(paths: paths)
        let vhost = gen.frontVhostText(for: proxySite("app.test", target: "https://api.example.com"))
        XCTAssertTrue(vhost.contains("proxy_pass https://api.example.com:443;"))
        XCTAssertTrue(vhost.contains("proxy_ssl_server_name on;"))
        XCTAssertTrue(vhost.contains("proxy_set_header Host api.example.com;"))
    }

    func testSecureProxyVhostHasNoRoot() throws {
        let (paths, root) = makePaths(); defer { try? fm.removeItem(at: root) }
        let certDir = paths.siteCertDir("app.test")
        try fm.createDirectory(at: certDir, withIntermediateDirectories: true)
        try Data().write(to: paths.siteCert("app.test"))
        try Data().write(to: paths.siteKey("app.test"))

        let gen = SiteConfigGenerator(paths: paths)
        let vhost = gen.frontVhostText(for: proxySite("app.test", target: "http://127.0.0.1:8000", secure: true))
        XCTAssertTrue(vhost.contains("listen 0.0.0.0:443 ssl;"))
        XCTAssertTrue(vhost.contains("return 301 https://$host$request_uri;"))
        XCTAssertTrue(vhost.contains("proxy_pass http://127.0.0.1:8000;"))
        XCTAssertFalse(vhost.contains("root \""))
        XCTAssertFalse(vhost.contains("index "))
    }

    func testInvalidTargetWritesNoVhost() throws {
        let (paths, root) = makePaths(); defer { try? fm.removeItem(at: root) }
        let gen = SiteConfigGenerator(paths: paths)
        let site = proxySite("bad.test", target: "http://127.0.0.1:8000/api")
        _ = try gen.generate(sites: [site])
        XCTAssertFalse(fm.fileExists(atPath: paths.vhost("bad.test").path))
    }

    func testValidTargetWritesVhost() throws {
        let (paths, root) = makePaths(); defer { try? fm.removeItem(at: root) }
        let gen = SiteConfigGenerator(paths: paths)
        let site = proxySite("ok.test", target: "http://127.0.0.1:8000")
        _ = try gen.generate(sites: [site])
        XCTAssertTrue(fm.fileExists(atPath: paths.vhost("ok.test").path))
        let written = try String(contentsOf: paths.vhost("ok.test"), encoding: .utf8)
        XCTAssertTrue(written.contains("proxy_pass http://127.0.0.1:8000;"))
    }
}
