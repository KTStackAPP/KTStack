import XCTest
@testable import KTStackKit

final class ApacheConfigWriterTests: XCTestCase {
    private let paths = AppSupportPaths(root: URL(fileURLWithPath: "/tmp/ktstack-test"))

    private func config(secure: Bool) -> String {
        let backend = ApacheBackend(serverRoot: paths.apacheRoot)
        return backend.backendConfig(context: BackendRenderContext(
            domain: "demo.test",
            root: URL(fileURLWithPath: "/s/public"),
            phpFpmSocket: paths.phpFpmSocket("8.4"),
            backendPort: 4002,
            secure: secure,
            pidFile: paths.siteBackendPid("ID"),
            accessLog: paths.siteAccessLog("demo.test"),
            errorLog: paths.siteErrorLog("demo.test")
        ))
    }

    func testListensOnLoopbackBackendPort() {
        let c = config(secure: false)
        XCTAssertTrue(c.contains("Listen 127.0.0.1:4002"))
        XCTAssertTrue(c.contains("<VirtualHost 127.0.0.1:4002>"))
    }

    func testProxiesPHPToFPMUnixSocketViaProxyFcgi() {
        let c = config(secure: false)
        XCTAssertTrue(c.contains("LoadModule proxy_fcgi_module modules/mod_proxy_fcgi.so"))
        XCTAssertTrue(c.contains("SetHandler \"proxy:unix:\(paths.phpFpmSocket("8.4").path)|fcgi://localhost/\""))
    }

    func testHtaccessSupportEnabled() {
        XCTAssertTrue(config(secure: false).contains("AllowOverride All"))
    }

    func testFrontControllerRoutesNonFileURLsToIndexPhp() {
        // Mirrors the nginx backend's try_files → /index.php so pretty URLs don't 404.
        XCTAssertTrue(config(secure: false).contains("FallbackResource /index.php"))
    }

    func testSecurePinsCanonicalPort443AndHTTPSEnv() {
        let c = config(secure: true)
        XCTAssertTrue(c.contains("UseCanonicalName On"))
        XCTAssertTrue(c.contains("ServerName demo.test:443"))
        XCTAssertTrue(c.contains("SetEnv HTTPS on"))
    }

    func testInsecurePinsPort80AndOmitsHTTPS() {
        let c = config(secure: false)
        XCTAssertTrue(c.contains("ServerName demo.test:80"))
        XCTAssertFalse(c.contains("SetEnv HTTPS on"))
    }

    func testNoTLSAtBackend() {
        XCTAssertFalse(config(secure: true).contains("mod_ssl"))
        XCTAssertFalse(config(secure: true).contains("SSLEngine"))
    }

    func testFactoryFallsBackToNginxWhenApacheBinaryMissing() {
        // /tmp/ktstack-test has no httpd binary → apache request degrades to nginx.
        XCTAssertEqual(WebServerBackendFactory.effectiveEngine(.apache, paths: paths), .nginx)
        XCTAssertEqual(WebServerBackendFactory.effectiveEngine(.nginx, paths: paths), .nginx)
    }
}
