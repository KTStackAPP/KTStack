import XCTest
@testable import KTStackKit

@MainActor
final class SiteRegistryReinspectTests: XCTestCase {
    private let fm = FileManager.default

    private func makeRegistry() throws -> (SiteRegistry, URL) {
        let root = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("kd-reinspect-\(UUID().uuidString)", isDirectory: true)
        try fm.createDirectory(at: root, withIntermediateDirectories: true)
        let store = root.appendingPathComponent("sites.json")
        return (SiteRegistry(storeURL: store, tld: "test"), root)
    }

    private func addStaticSite(to registry: SiteRegistry, root: URL) throws -> (Site, URL) {
        let folder = root.appendingPathComponent("site", isDirectory: true)
        try fm.createDirectory(at: folder, withIntermediateDirectories: true)
        let site = try registry.add(folder: folder)
        XCTAssertEqual(site.type, .staticSite)
        XCTAssertNil(site.backendPort)
        XCTAssertNil(site.nodePort)
        return (site, folder)
    }

    func testReinspectStaticToPHPAssignsBackendPort() throws {
        let (registry, root) = try makeRegistry()
        defer { try? fm.removeItem(at: root) }
        let (site, folder) = try addStaticSite(to: registry, root: root)

        try "<?php".write(to: folder.appendingPathComponent("index.php"), atomically: true, encoding: .utf8)
        let type = registry.reinspect(site)

        XCTAssertEqual(type, .php)
        let updated = try XCTUnwrap(registry.sites.first { $0.id == site.id })
        XCTAssertEqual(updated.type, .php)
        XCTAssertNotNil(updated.backendPort)
    }

    func testReinspectStaticToNodeAssignsNodePort() throws {
        let (registry, root) = try makeRegistry()
        defer { try? fm.removeItem(at: root) }
        let (site, folder) = try addStaticSite(to: registry, root: root)

        try #"{"name": "app"}"#.write(
            to: folder.appendingPathComponent("package.json"), atomically: true, encoding: .utf8
        )
        let type = registry.reinspect(site)

        XCTAssertEqual(type, .node)
        let updated = try XCTUnwrap(registry.sites.first { $0.id == site.id })
        XCTAssertEqual(updated.type, .node)
        XCTAssertNotNil(updated.nodePort)
    }

    func testReinspectPHPToStaticKeepsBackendPort() throws {
        let (registry, root) = try makeRegistry()
        defer { try? fm.removeItem(at: root) }
        let folder = root.appendingPathComponent("site", isDirectory: true)
        try fm.createDirectory(at: folder, withIntermediateDirectories: true)
        let index = folder.appendingPathComponent("index.php")
        try "<?php".write(to: index, atomically: true, encoding: .utf8)
        let site = try registry.add(folder: folder)
        let port = try XCTUnwrap(site.backendPort)

        try fm.removeItem(at: index)
        XCTAssertEqual(registry.reinspect(site), .staticSite)

        // Giữ port để flip ngược lại không phải cấp mới; generator/supervisor gate theo type.
        let updated = try XCTUnwrap(registry.sites.first { $0.id == site.id })
        XCTAssertEqual(updated.type, .staticSite)
        XCTAssertEqual(updated.backendPort, port)
    }

    func testReinspectWithoutChangeKeepsSite() throws {
        let (registry, root) = try makeRegistry()
        defer { try? fm.removeItem(at: root) }
        let (site, _) = try addStaticSite(to: registry, root: root)

        XCTAssertEqual(registry.reinspect(site), .staticSite)
        let updated = try XCTUnwrap(registry.sites.first { $0.id == site.id })
        XCTAssertEqual(updated.type, .staticSite)
        XCTAssertNil(updated.nodePort)
        XCTAssertNil(updated.backendPort)
    }
}
