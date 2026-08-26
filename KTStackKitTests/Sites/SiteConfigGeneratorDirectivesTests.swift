import KTStackCore
import XCTest
@testable import KTStackKit

final class SiteConfigGeneratorDirectivesTests: XCTestCase {
    private let fm = FileManager.default

    private func makePaths() -> (AppSupportPaths, URL) {
        let root = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("kd-directives-\(UUID().uuidString)", isDirectory: true)
        let p = AppSupportPaths(root: root)
        try? p.ensureDirectoryTree()
        return (p, root)
    }

    private func staticSite(_ domain: String, directives: String?) -> Site {
        Site(
            name: domain,
            path: "/tmp/\(domain)",
            docroot: "/tmp/\(domain)",
            domain: domain,
            phpVersion: "8.4",
            type: .staticSite,
            frontDirectives: directives
        )
    }

    func testDirectivesFileWrittenAndIncluded() throws {
        let (p, root) = makePaths(); defer { try? fm.removeItem(at: root) }
        let gen = SiteConfigGenerator(paths: p)
        let site = staticSite("a.test", directives: "  add_header X-KT on;  ")
        try gen.generate(sites: [site])

        let confFile = p.siteDirectivesConf(site.id.uuidString)
        XCTAssertTrue(fm.fileExists(atPath: confFile.path))
        let written = try String(contentsOf: confFile, encoding: .utf8)
        XCTAssertEqual(written, "add_header X-KT on;\n")

        let vhost = try String(contentsOf: p.vhost(site.domain), encoding: .utf8)
        XCTAssertTrue(vhost.contains("include \"\(confFile.path)\";"))
    }

    func testEmptyDirectivesWritesNoFileNorInclude() throws {
        let (p, root) = makePaths(); defer { try? fm.removeItem(at: root) }
        let gen = SiteConfigGenerator(paths: p)
        let site = staticSite("a.test", directives: "   \n  ")
        try gen.generate(sites: [site])

        XCTAssertFalse(fm.fileExists(atPath: p.siteDirectivesConf(site.id.uuidString).path))
        let vhost = try String(contentsOf: p.vhost(site.domain), encoding: .utf8)
        XCTAssertFalse(vhost.contains("include \"\(p.siteDirectivesDir.path)"))
    }

    func testOrphanDirectivesRemovedWhenSiteDropsThem() throws {
        let (p, root) = makePaths(); defer { try? fm.removeItem(at: root) }
        let gen = SiteConfigGenerator(paths: p)
        let with = staticSite("a.test", directives: "add_header X-KT on;")
        try gen.generate(sites: [with])
        XCTAssertTrue(fm.fileExists(atPath: p.siteDirectivesConf(with.id.uuidString).path))

        var without = with
        without.frontDirectives = nil
        try gen.generate(sites: [without])
        XCTAssertFalse(fm.fileExists(atPath: p.siteDirectivesConf(with.id.uuidString).path))
    }
}
