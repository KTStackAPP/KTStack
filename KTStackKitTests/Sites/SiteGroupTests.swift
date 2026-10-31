import KTPlatformContracts
import XCTest
@testable import KTStackKit

@MainActor
final class SiteGroupTests: XCTestCase {
    private let fm = FileManager.default
    private var root: URL!
    private var store: URL { root.appendingPathComponent("sites.json") }

    override func setUpWithError() throws {
        root = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("kd-group-\(UUID().uuidString)", isDirectory: true)
        try fm.createDirectory(at: root, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? fm.removeItem(at: root)
    }

    private func site(group: String? = nil) -> Site {
        Site(
            name: "shop", path: "/tmp/shop", docroot: "/tmp/shop", domain: "shop.test",
            phpVersion: "8.3", type: .php, backendPort: 4100, group: group
        )
    }

    func testOldSitesJSONLoadsUngroupedAndNothingIsRejected() throws {
        let json = """
        [{"name":"shop","path":"/s","docroot":"/s","domain":"shop.test","phpVersion":"8.4","type":"php"}]
        """
        try Data(json.utf8).write(to: store)
        let registry = SiteRegistry(storeURL: store, tld: "test")

        XCTAssertEqual(registry.sites.count, 1)
        XCTAssertNil(registry.sites.first?.group)
        XCTAssertFalse(try fm.contentsOfDirectory(atPath: root.path).contains { $0.hasPrefix("sites.rejected-") })
    }

    func testGroupRoundTripsThroughJSON() throws {
        let data = try JSONEncoder().encode(site(group: "Archive"))
        XCTAssertEqual(try JSONDecoder().decode(Site.self, from: data).group, "Archive")
    }

    func testUngroupedSiteWritesNoGroupKey() throws {
        let object = try JSONSerialization.jsonObject(with: JSONEncoder().encode(site())) as? [String: Any]
        XCTAssertNotNil(object)
        XCTAssertFalse(object?.keys.contains("group") ?? true)
    }

    func testNormalizeTrimsAndCollapsesSpaces() throws {
        XCTAssertEqual(try SiteGroupName.normalize("  Client   Work \n"), "Client Work")
        XCTAssertNil(try SiteGroupName.normalize("   "))
        XCTAssertEqual(try SiteGroupName.normalize(String(repeating: "a", count: 40)), String(repeating: "a", count: 40))
        XCTAssertThrowsError(try SiteGroupName.normalize(String(repeating: "a", count: 41))) {
            XCTAssertEqual($0 as? SiteGroupError, .tooLong)
        }
    }

    func testSetGroupPersistsAcrossReload() throws {
        let registry = SiteRegistry(storeURL: store, tld: "test")
        registry.sites = [site()]
        let added = try XCTUnwrap(registry.sites.first)

        try registry.setGroup(added, "  Current ")
        XCTAssertEqual(SiteRegistry(storeURL: store, tld: "test").sites.first?.group, "Current")

        try registry.setGroup(added, nil)
        XCTAssertNil(SiteRegistry(storeURL: store, tld: "test").sites.first?.group)
    }

    func testSetGroupRejectsTooLongNameAndKeepsTheOldOne() throws {
        let registry = SiteRegistry(storeURL: store, tld: "test")
        registry.sites = [site(group: "Current")]
        let added = try XCTUnwrap(registry.sites.first)

        XCTAssertThrowsError(try registry.setGroup(added, String(repeating: "x", count: 41)))
        XCTAssertEqual(registry.sites.first?.group, "Current")
    }
}
