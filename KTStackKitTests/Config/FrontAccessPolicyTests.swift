import KTStackCore
import XCTest
@testable import KTStackKit

final class FrontAccessPolicyTests: XCTestCase {
    private let paths = AppSupportPaths(root: URL(fileURLWithPath: "/tmp/kt-front-access"))

    private func httpPrelude(_ conf: String) -> String {
        conf.components(separatedBy: "server {").first ?? conf
    }

    func testFrontIsLoopbackOnlyByDefault() {
        let conf = NginxConfigWriter().masterConfig(paths: paths, allowLAN: false)
        let prelude = httpPrelude(conf)
        XCTAssertTrue(prelude.contains("    allow 127.0.0.1;\n    allow ::1;\n    deny all;\n    include "), prelude)
        XCTAssertTrue(conf.contains("listen 0.0.0.0:80 default_server;"))
    }

    func testLANOptInDropsTheDenyRule() {
        let conf = NginxConfigWriter().masterConfig(paths: paths, allowLAN: true)
        XCTAssertFalse(httpPrelude(conf).contains("deny all;"))
    }

    func testPreferenceDefaultsToOffForUpgraders() throws {
        let defaults = try XCTUnwrap(UserDefaults(suiteName: "kt-front-\(UUID().uuidString)"))
        XCTAssertFalse(FrontAccessPolicy.allowsLAN(defaults: defaults))
        defaults.set(true, forKey: FrontAccessPolicy.defaultsKey)
        XCTAssertTrue(FrontAccessPolicy.allowsLAN(defaults: defaults))
    }

    func testBackendTrustsTheFrontForTheClientAddress() {
        let conf = NginxBackendConfigWriter().config(
            domain: "demo.test", root: URL(fileURLWithPath: "/s"), phpFpmSocket: URL(fileURLWithPath: "/s.sock"),
            backendPort: 4001, secure: false, pid: URL(fileURLWithPath: "/p"),
            accessLog: URL(fileURLWithPath: "/a"), errorLog: URL(fileURLWithPath: "/e")
        )
        XCTAssertTrue(conf.contains("listen 127.0.0.1:4001;\n        set_real_ip_from 127.0.0.1;\n        real_ip_header X-Real-IP;"), conf)
        XCTAssertTrue(conf.contains("fastcgi_param REMOTE_ADDR      $remote_addr;"))
    }

    func testApacheLoadsRemoteIPOnlyWhenShipped() {
        XCTAssertTrue(ApacheBackend.remoteIPBlock.contains("<IfFile modules/mod_remoteip.so>"))
        XCTAssertTrue(ApacheBackend.remoteIPBlock.contains("RemoteIPHeader X-Real-IP"))
    }
}
