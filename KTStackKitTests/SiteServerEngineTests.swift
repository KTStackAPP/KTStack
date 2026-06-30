import XCTest
@testable import KTStackKit

final class SiteServerEngineTests: XCTestCase {
    func testEngineRawValuesAreFrozen() {
        XCTAssertEqual(WebServerEngine.nginx.rawValue, "nginx")
        XCTAssertEqual(WebServerEngine.apache.rawValue, "apache")
    }

    func testPreUpgradeJSONDecodesToNginx() throws {
        let json = """
        {"name":"demo","path":"/s","docroot":"/s/public","domain":"demo.test","phpVersion":"8.4","type":"php"}
        """
        let site = try JSONDecoder().decode(Site.self, from: Data(json.utf8))
        XCTAssertEqual(site.serverEngine, .nginx)
    }

    func testEngineRoundTrips() throws {
        var site = Site(name: "demo", path: "/s", docroot: "/s/public", domain: "demo.test", phpVersion: "8.4", type: .php)
        site.serverEngine = .apache
        let data = try JSONEncoder().encode(site)
        let decoded = try JSONDecoder().decode(Site.self, from: data)
        XCTAssertEqual(decoded.serverEngine, .apache)
    }

    func testDefaultEngineIsNginx() {
        let site = Site(name: "demo", path: "/s", docroot: "/s/public", domain: "demo.test", phpVersion: "8.4", type: .php)
        XCTAssertEqual(site.serverEngine, .nginx)
    }

    func testPreUpgradeJSONDecodesBackendPortAsNil() throws {
        let json = """
        {"name":"demo","path":"/s","docroot":"/s/public","domain":"demo.test","phpVersion":"8.4","type":"php"}
        """
        let site = try JSONDecoder().decode(Site.self, from: Data(json.utf8))
        XCTAssertNil(site.backendPort)
    }

    func testBackendPortRoundTripsUnderFrozenKey() throws {
        var site = Site(name: "demo", path: "/s", docroot: "/s/public", domain: "demo.test", phpVersion: "8.4", type: .php)
        site.backendPort = 4007
        let data = try JSONEncoder().encode(site)
        let raw = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        XCTAssertEqual(raw["backendPort"] as? Int, 4007)
        let decoded = try JSONDecoder().decode(Site.self, from: data)
        XCTAssertEqual(decoded.backendPort, 4007)
    }
}
