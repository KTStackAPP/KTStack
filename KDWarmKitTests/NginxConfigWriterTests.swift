import XCTest
@testable import KDWarmKit

/// The load-bearing invariant of the HTTP slice: generated vhosts MUST listen on the
/// wildcard `0.0.0.0` (bindable without root) and NEVER on a specific loopback interface
/// (`127.0.0.1`, which returns EACCES for a privileged port as a non-root user).
final class NginxConfigWriterTests: XCTestCase {
    private let writer = NginxConfigWriter()
    private let paths = AppSupportPaths(root: URL(fileURLWithPath: "/tmp/kdwarm-test"))

    func testVhostListensOnWildcardNotLoopback() {
        let vhost = writer.vhost(
            domain: "demo.test",
            root: URL(fileURLWithPath: "/Users/me/Sites/WWW/demo/public"),
            phpFpmSocket: paths.phpFpmSocket("demo"))

        XCTAssertTrue(vhost.contains("listen 0.0.0.0:80;"),
                      "vhost must bind the wildcard privileged port")
        XCTAssertFalse(vhost.contains("127.0.0.1"),
                       "vhost must never bind a specific loopback interface (EACCES without root)")
    }

    func testCustomPortStillWildcard() {
        let vhost = writer.vhost(
            domain: "demo.test",
            root: URL(fileURLWithPath: "/tmp/site"),
            phpFpmSocket: paths.phpFpmSocket("demo"),
            port: 8080)
        XCTAssertTrue(vhost.contains("listen 0.0.0.0:8080;"))
        XCTAssertFalse(vhost.contains("127.0.0.1"))
    }

    func testListenAddressConstantIsWildcard() {
        XCTAssertEqual(NginxConfigWriter.listenAddress, "0.0.0.0")
    }

    func testVhostWiresFastcgiToPoolSocket() {
        let socket = paths.phpFpmSocket("demo")
        let vhost = writer.vhost(domain: "demo.test",
                                 root: URL(fileURLWithPath: "/tmp/site"),
                                 phpFpmSocket: socket)
        XCTAssertTrue(vhost.contains("fastcgi_pass unix:\(socket.path);"))
        XCTAssertTrue(vhost.contains("server_name demo.test;"))
    }

    func testDomainAndPathValidationRejectInjection() {
        XCTAssertTrue(NginxConfigWriter.isValidDomain("demo.test"))
        XCTAssertFalse(NginxConfigWriter.isValidDomain("demo.test;\n} server {"))
        XCTAssertFalse(NginxConfigWriter.isValidDomain("a b"))
        XCTAssertTrue(NginxConfigWriter.isSafePath("/Users/me/Sites/demo/public"))
        XCTAssertFalse(NginxConfigWriter.isSafePath("/tmp/x;\nroot /etc"))
    }

    func testWriteDemoThrowsOnBadDomain() {
        let tmp = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("kdwarm-\(UUID())")
        let p = AppSupportPaths(root: tmp)
        try? p.ensureDirectoryTree()
        defer { try? FileManager.default.removeItem(at: tmp) }
        XCTAssertThrowsError(try writer.writeDemo(
            paths: p, domain: "bad;domain", siteRoot: URL(fileURLWithPath: "/tmp/site"), poolName: "demo"))
    }

    func testMasterConfigIncludesSitesEnabled() {
        let conf = writer.masterConfig(paths: paths)
        XCTAssertTrue(conf.contains("include \(paths.sitesEnabled.path)/*.conf;"))
        XCTAssertTrue(conf.contains("error_log \(paths.nginxErrorLog.path)"))
    }
}
