import KTStackCore
import XCTest
@testable import KTStackKit

@MainActor
final class RegistryResilienceTests: XCTestCase {
    private let fm = FileManager.default
    private var root: URL!

    override func setUpWithError() throws {
        root = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("kd-resilience-\(UUID().uuidString)")
        try fm.createDirectory(at: root, withIntermediateDirectories: true)
    }

    override func tearDown() {
        try? fm.removeItem(at: root)
    }

    private var store: URL { root.appendingPathComponent("sites.json") }

    private func site(_ name: String, path: String, type: SiteType = .php) -> Site {
        Site(name: name, path: path, docroot: path, domain: "\(name).test", phpVersion: "8.3", type: type, backendPort: 4100)
    }

    private func siteJSON(_ site: Site) throws -> Any {
        try JSONSerialization.jsonObject(with: JSONEncoder().encode(site))
    }

    func testCorruptRegistryIsNeverOverwritten() throws {
        try Data("{not json".utf8).write(to: store)
        let registry = SiteRegistry(storeURL: store, tld: "test")

        XCTAssertNotNil(registry.loadFailure)
        let folder = root.appendingPathComponent("app", isDirectory: true)
        try fm.createDirectory(at: folder, withIntermediateDirectories: true)
        _ = try? registry.add(folder: folder)

        XCTAssertEqual(try String(contentsOf: store, encoding: .utf8), "{not json")
        XCTAssertTrue(try fm.contentsOfDirectory(atPath: root.path).contains { $0.hasPrefix("sites.json.bak-") })
    }

    func testOneBadEntryDoesNotDropTheOthers() throws {
        let good = site("good", path: "/Users/dev/good")
        let entries: [Any] = [try siteJSON(good), ["name": "broken"]]
        try JSONSerialization.data(withJSONObject: entries).write(to: store)

        let registry = SiteRegistry(storeURL: store, tld: "test")

        XCTAssertNil(registry.loadFailure)
        XCTAssertEqual(registry.sites.map(\.name), ["good"])
        let rejected = try fm.contentsOfDirectory(atPath: root.path).filter { $0.hasPrefix("sites.rejected-") }
        XCTAssertEqual(rejected.count, 1)
        let saved = try String(contentsOf: root.appendingPathComponent(rejected[0]), encoding: .utf8)
        XCTAssertTrue(saved.contains("broken"))
    }

    func testPruneSetsOrphanedCertsAside() throws {
        let paths = AppSupportPaths(root: root.appendingPathComponent("support"))
        try paths.ensureDirectoryTree()
        try fm.createDirectory(at: paths.siteCertDir("gone.test"), withIntermediateDirectories: true)
        try Data("pem".utf8).write(to: paths.siteCertDir("gone.test").appendingPathComponent("cert.pem"))

        CertMinter(paths: paths, runner: MkcertRunner(mkcert: paths.mkcertBinary, caroot: paths.caDir)).pruneOrphans(keeping: [])

        XCTAssertFalse(fm.fileExists(atPath: paths.siteCertDir("gone.test").path))
        let pruned = CertPruneStore(certsDir: paths.certsDir).prunedDir
        let kept = try fm.contentsOfDirectory(atPath: pruned.path)
        XCTAssertEqual(kept.count, 1)
        XCTAssertTrue(fm.fileExists(atPath: pruned.appendingPathComponent(kept[0]).appendingPathComponent("cert.pem").path))
    }

    func testRuntimePinsIgnoreProxySitesAndRelativePaths() throws {
        var proxy = site("api", path: "", type: .proxy)
        proxy.phpVersion = "7.4"
        var relative = site("rel", path: "relative/app")
        relative.phpVersion = "8.1"
        var php = site("shop", path: "/Users/dev/shop")
        php.phpVersion = "8.2"
        let entries: [Any] = [try siteJSON(proxy), try siteJSON(relative), ["garbage": true], try siteJSON(php)]
        try JSONSerialization.data(withJSONObject: entries).write(to: store)

        let pins = SiteRuntimePins(storeURL: store)

        XCTAssertNil(pins.phpVersion(forProjectAt: URL(fileURLWithPath: "/Users/dev/other")))
        XCTAssertNil(pins.phpVersion(forProjectAt: URL(fileURLWithPath: FileManager.default.currentDirectoryPath)))
        XCTAssertEqual(pins.phpVersion(forProjectAt: URL(fileURLWithPath: "/Users/dev/shop/src")), "8.2")
    }
}
