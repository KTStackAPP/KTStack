import XCTest
@testable import KTStackKit

final class NginxBackendSnapshotTests: XCTestCase {
    private let backend = NginxBackend()
    private let writer = NginxBackendConfigWriter()
    private let paths = AppSupportPaths(root: URL(fileURLWithPath: "/tmp/ktstack-test"))

    private func context(domain: String, secure: Bool) -> BackendRenderContext {
        BackendRenderContext(
            domain: domain,
            root: URL(fileURLWithPath: "/s/public"),
            phpFpmSocket: paths.phpFpmSocket("8.4"),
            backendPort: 4001,
            secure: secure,
            pidFile: paths.siteBackendPid("ID"),
            accessLog: paths.siteAccessLog(domain),
            errorLog: paths.siteErrorLog(domain)
        )
    }

    func testBackendConfigDelegatesToWriter() {
        let ctx = context(domain: "demo.test", secure: false)
        let expected = writer.config(
            domain: "demo.test",
            root: ctx.root,
            phpFpmSocket: ctx.phpFpmSocket,
            backendPort: 4001,
            secure: false,
            pid: ctx.pidFile,
            accessLog: ctx.accessLog,
            errorLog: ctx.errorLog
        )
        XCTAssertEqual(backend.backendConfig(context: ctx), expected)
    }

    func testInsecureBackendPinsPort80AndOmitsHTTPS() {
        let config = backend.backendConfig(context: context(domain: "demo.test", secure: false))
        XCTAssertTrue(config.contains("listen 127.0.0.1:4001;"))
        XCTAssertTrue(config.contains("fastcgi_param SERVER_PORT      80;"))
        XCTAssertTrue(config.contains("fastcgi_param SERVER_ADDR      127.0.0.1;"))
        XCTAssertFalse(config.contains("fastcgi_param HTTPS"))
    }

    func testSecureBackendPinsPort443AndHTTPSOn() {
        let config = backend.backendConfig(context: context(domain: "demo.test", secure: true))
        XCTAssertTrue(config.contains("fastcgi_param SERVER_PORT      443;"))
        XCTAssertTrue(config.contains("fastcgi_param HTTPS            on;"))
        // The loopback port must never leak into SERVER_PORT (would break redirect URLs).
        XCTAssertFalse(config.contains("SERVER_PORT      4001"))
        XCTAssertFalse(config.contains("$server_port"))
    }

    func testFactoryReturnsNginxForNginxEngine() {
        XCTAssertEqual(WebServerBackendFactory.backend(for: .nginx, paths: paths).engine, .nginx)
    }
}
