import KTStackCore
import XCTest
@testable import KTStackKit

final class SiteNodeCodableTests: XCTestCase {
    func testDecodesLegacySiteWithoutNodeFields() throws {
        let legacy = """
        {
            "id": "11111111-1111-1111-1111-111111111111",
            "name": "demo",
            "path": "/tmp/demo",
            "docroot": "/tmp/demo/public",
            "domain": "demo.test",
            "phpVersion": "8.4",
            "type": "php",
            "secure": false
        }
        """.data(using: .utf8)!

        let site = try JSONDecoder().decode(Site.self, from: legacy)
        XCTAssertNil(site.nodePort)
        XCTAssertNil(site.nodeCommand)
        XCTAssertFalse(site.nodeEnabled)
        XCTAssertEqual(site.domain, "demo.test")
    }

    func testDecodesLegacySiteWithoutSecureField() throws {
        let legacy = """
        {
            "id": "22222222-2222-2222-2222-222222222222",
            "name": "old",
            "path": "/tmp/old",
            "docroot": "/tmp/old",
            "domain": "old.test",
            "phpVersion": "8.4",
            "type": "staticSite"
        }
        """.data(using: .utf8)!

        let site = try JSONDecoder().decode(Site.self, from: legacy)
        XCTAssertFalse(site.secure)
        XCTAssertFalse(site.nodeEnabled)
    }

    func testDecodesLegacySiteWithoutProxyTarget() throws {
        let legacy = """
        {
            "id": "33333333-3333-3333-3333-333333333333",
            "name": "demo",
            "path": "/tmp/demo",
            "docroot": "/tmp/demo/public",
            "domain": "demo.test",
            "phpVersion": "8.4",
            "type": "php",
            "secure": false
        }
        """.data(using: .utf8)!

        let site = try JSONDecoder().decode(Site.self, from: legacy)
        XCTAssertNil(site.proxyTarget)
        XCTAssertNil(site.proxyUpstream)
        XCTAssertTrue(site.hasFolder)
    }

    func testRoundTripPreservesProxyTarget() throws {
        let original = Site(
            name: "api",
            path: "",
            docroot: "",
            domain: "api.test",
            phpVersion: "8.4",
            type: .proxy,
            proxyTarget: "http://127.0.0.1:8000"
        )
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(Site.self, from: data)
        XCTAssertEqual(decoded.proxyTarget, "http://127.0.0.1:8000")
        XCTAssertEqual(decoded.proxyUpstream, .loopback(port: 8000))
        XCTAssertFalse(decoded.hasFolder)
        XCTAssertEqual(decoded, original)
    }

    func testDecodesLegacySiteWithoutAliasEnvDirectives() throws {
        let legacy = """
        {
            "id": "44444444-4444-4444-4444-444444444444",
            "name": "demo",
            "path": "/tmp/demo",
            "docroot": "/tmp/demo/public",
            "domain": "demo.test",
            "phpVersion": "8.4",
            "type": "php",
            "secure": false
        }
        """.data(using: .utf8)!

        let site = try JSONDecoder().decode(Site.self, from: legacy)
        XCTAssertEqual(site.aliases, [])
        XCTAssertEqual(site.envVars, [:])
        XCTAssertNil(site.frontDirectives)
        XCTAssertFalse(site.hasFrontDirectives)
    }

    func testRoundTripPreservesAliasEnvDirectives() throws {
        let original = Site(
            name: "demo",
            path: "/tmp/demo",
            docroot: "/tmp/demo/public",
            domain: "demo.test",
            phpVersion: "8.4",
            type: .php,
            aliases: ["api.demo.test", "cdn.demo.test"],
            envVars: ["APP_DEBUG": "1", "APP_ENV": "local"],
            frontDirectives: "add_header X-KT test;"
        )
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(Site.self, from: data)
        XCTAssertEqual(decoded.aliases, ["api.demo.test", "cdn.demo.test"])
        XCTAssertEqual(decoded.envVars, ["APP_DEBUG": "1", "APP_ENV": "local"])
        XCTAssertEqual(decoded.frontDirectives, "add_header X-KT test;")
        XCTAssertEqual(decoded.serverNames, ["demo.test", "api.demo.test", "cdn.demo.test"])
        XCTAssertTrue(decoded.hasFrontDirectives)
        XCTAssertEqual(decoded, original)
    }

    func testRoundTripPreservesNodeFields() throws {
        let original = Site(
            name: "app",
            path: "/tmp/app",
            docroot: "/tmp/app",
            domain: "app.test",
            phpVersion: "8.4",
            type: .node,
            nodePort: 3001,
            nodeCommand: "npm run dev",
            nodeEnabled: true
        )
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(Site.self, from: data)
        XCTAssertEqual(decoded.nodePort, 3001)
        XCTAssertEqual(decoded.nodeCommand, "npm run dev")
        XCTAssertTrue(decoded.nodeEnabled)
        XCTAssertEqual(decoded, original)
    }
}
