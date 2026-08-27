import KTStackCore
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
            pidFile: paths.siteBackendPid("ID", engine: "nginx"),
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

    func testBackendKeepsNativeRedirectsRelative() {
        let config = backend.backendConfig(context: context(domain: "demo.test", secure: true))
        XCTAssertTrue(config.contains("absolute_redirect off;"))
    }

    func testBackendRendersSortedEnvAndAliases() {
        let ctx = BackendRenderContext(
            domain: "demo.test",
            root: URL(fileURLWithPath: "/s/public"),
            phpFpmSocket: paths.phpFpmSocket("8.4"),
            backendPort: 4001,
            secure: false,
            pidFile: paths.siteBackendPid("ID", engine: "nginx"),
            accessLog: paths.siteAccessLog("demo.test"),
            errorLog: paths.siteErrorLog("demo.test"),
            aliases: ["api.demo.test"],
            env: ["B_KEY": "two", "A_KEY": "has space"]
        )
        let config = backend.backendConfig(context: ctx)
        XCTAssertTrue(config.contains("server_name demo.test api.demo.test;"))
        XCTAssertTrue(config.contains("fastcgi_param A_KEY \"has space\";"))
        XCTAssertTrue(config.contains("fastcgi_param B_KEY \"two\";"))
        guard let a = config.range(of: "fastcgi_param A_KEY")?.lowerBound,
              let b = config.range(of: "fastcgi_param B_KEY")?.lowerBound
        else { return XCTFail("env params missing") }
        XCTAssertLessThan(a, b, "env params render sorted by key")
    }

    func testBackendEmptyEnvMatchesBase() {
        let config = backend.backendConfig(context: context(domain: "demo.test", secure: false))
        let base = writer.config(
            domain: "demo.test",
            root: URL(fileURLWithPath: "/s/public"),
            phpFpmSocket: paths.phpFpmSocket("8.4"),
            backendPort: 4001,
            secure: false,
            pid: paths.siteBackendPid("ID", engine: "nginx"),
            accessLog: paths.siteAccessLog("demo.test"),
            errorLog: paths.siteErrorLog("demo.test")
        )
        XCTAssertEqual(config, base)
    }

    func testFactoryReturnsNginxForNginxEngine() {
        XCTAssertEqual(WebServerBackendFactory.backend(for: .nginx, paths: paths).engine, .nginx)
    }
}
