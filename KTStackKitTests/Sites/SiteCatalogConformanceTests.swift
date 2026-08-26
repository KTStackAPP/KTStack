import KTPlatformContracts
import KTStackCore
import XCTest
@testable import KTStackKit

@MainActor
final class SiteCatalogConformanceTests: XCTestCase {
    private let fm = FileManager.default

    private func makeServer() throws -> (LocalServerController, AppSupportPaths) {
        let root = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("kd-catalog-\(UUID().uuidString)", isDirectory: true)
        let paths = AppSupportPaths(root: root)
        try paths.ensureDirectoryTree()
        let server = LocalServerController(bundleBinDir: URL(fileURLWithPath: "/dev/null"), paths: paths)
        return (server, paths)
    }

    private func phpFolder(in dir: URL, named: String) throws -> URL {
        let f = dir.appendingPathComponent(named, isDirectory: true)
        try fm.createDirectory(at: f, withIntermediateDirectories: true)
        try "<?php".write(to: f.appendingPathComponent("index.php"), atomically: true, encoding: .utf8)
        return f
    }

    func testRawValuesFrozenMatchPlatformEnums() {
        XCTAssertEqual(SiteKind.allCases.map(\.rawValue), SiteType.allCases.map(\.rawValue))
        XCTAssertEqual(SiteServerEngine.allCases.map(\.rawValue), WebServerEngine.allCases.map(\.rawValue))
    }

    func testSiteSummaryMapsAllFourteenFields() {
        let id = UUID()
        let site = Site(
            id: id, name: "Shop", path: "/tmp/shop", docroot: "/tmp/shop/public",
            domain: "shop.test", phpVersion: "8.3", type: .php, databaseName: "shop_db",
            secure: true, nodePort: 3001, nodeCommand: "npm run dev",
            nodeEnabled: true, serverEngine: .apache, backendPort: 4001,
            proxyTarget: "http://127.0.0.1:8000"
        )
        let s = SiteSummary(site)
        XCTAssertEqual(s.id, id)
        XCTAssertEqual(s.name, "Shop")
        XCTAssertEqual(s.path, "/tmp/shop")
        XCTAssertEqual(s.docroot, "/tmp/shop/public")
        XCTAssertEqual(s.domain, "shop.test")
        XCTAssertEqual(s.phpVersion, "8.3")
        XCTAssertEqual(s.kind, .php)
        XCTAssertEqual(s.databaseName, "shop_db")
        XCTAssertTrue(s.secure)
        XCTAssertEqual(s.nodePort, 3001)
        XCTAssertEqual(s.nodeCommand, "npm run dev")
        XCTAssertEqual(s.engine, .apache)
        XCTAssertEqual(s.backendPort, 4001)
        XCTAssertEqual(s.proxyTarget, "http://127.0.0.1:8000")
    }

    func testCatalogReflectsRegistryAndTLD() throws {
        let (server, paths) = try makeServer()
        defer { try? fm.removeItem(at: paths.config.deletingLastPathComponent()) }
        let sitesRoot = paths.config.appendingPathComponent("scratch", isDirectory: true)
        try fm.createDirectory(at: sitesRoot, withIntermediateDirectories: true)
        let folder = try phpFolder(in: sitesRoot, named: "shop")
        try server.registry.add(folder: folder)

        let catalog = (server as any SiteCatalogManaging).catalog
        XCTAssertEqual(catalog.tld, "test")
        XCTAssertEqual(catalog.sites.count, 1)
        XCTAssertEqual(catalog.sites.first?.name, "shop")
        XCTAssertEqual(catalog.sites.first?.kind, .php)
    }

    func testCatalogStreamFirstValueEqualsCurrentThenYieldsOnChange() async throws {
        let (server, paths) = try makeServer()
        defer { try? fm.removeItem(at: paths.config.deletingLastPathComponent()) }
        let sitesRoot = paths.config.appendingPathComponent("scratch", isDirectory: true)
        try fm.createDirectory(at: sitesRoot, withIntermediateDirectories: true)
        let folder = try phpFolder(in: sitesRoot, named: "shop")
        let site = try server.registry.add(folder: folder)

        var iterator = (server as any SiteCatalogManaging).catalogStream().makeAsyncIterator()
        let first = await iterator.next()
        XCTAssertEqual(first, server.catalog)

        try (server as any SiteCatalogManaging).editDomain(site.id, "renamed.test")
        let next = await iterator.next()
        XCTAssertEqual(next?.sites.first?.domain, "renamed.test")
    }
}
