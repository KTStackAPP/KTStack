import KTStackCore
import XCTest
@testable import KTStackKit

final class SiteBackendSupervisorTests: XCTestCase {
    private func site(_ domain: String, type: SiteType, backendPort: Int?) -> Site {
        Site(name: domain, path: "/s", docroot: "/s", domain: domain, phpVersion: "8.4", type: type, backendPort: backendPort)
    }

    func testManagedKeepsOnlyPHPSitesWithABackendPort() {
        let sites = [
            site("a.test", type: .php, backendPort: 4001),
            site("b.test", type: .php, backendPort: nil), // not yet backfilled → excluded
            site("c.test", type: .staticSite, backendPort: nil),
            site("d.test", type: .node, backendPort: nil),
        ]
        XCTAssertEqual(SiteBackendSupervisor.managed(sites).map(\.domain), ["a.test"])
    }

    func testBackendPathsAreScopedPerSiteID() {
        let paths = AppSupportPaths(root: URL(fileURLWithPath: "/tmp/ktstack-test"))
        XCTAssertEqual(paths.siteBackendLabel("ABC", engine: "nginx"), "com.ktstack.site.ABC.nginx")
        XCTAssertEqual(paths.siteBackendLabel("ABC", engine: "apache"), "com.ktstack.site.ABC.apache")
        XCTAssertTrue(paths.siteBackendLabel("ABC", engine: "nginx").hasPrefix(SiteBackendSupervisor.labelPrefix))
        XCTAssertTrue(paths.siteBackendConf("ABC").path.hasSuffix("nginx/backends/ABC.conf"))
        XCTAssertTrue(paths.siteBackendPid("ABC", engine: "nginx").path.hasSuffix("run/site-ABC.nginx.pid"))
        XCTAssertTrue(paths.siteBackendPid("ABC", engine: "apache").path.hasSuffix("run/site-ABC.apache.pid"))
    }

    func testChangedConfsReportsOnlySitesWhoseBackendConfDiffers() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let paths = AppSupportPaths(root: root)
        try FileManager.default.createDirectory(at: paths.backendsConfigDir, withIntermediateDirectories: true)
        let supervisor = SiteBackendSupervisor(paths: paths, agents: LaunchAgentManager(paths: paths))
        let same = site("a.test", type: .php, backendPort: 4001)
        let edited = site("b.test", type: .php, backendPort: 4002)
        let added = site("c.test", type: .php, backendPort: 4003)
        let sites = [same, edited, added]
        try "a".write(to: paths.siteBackendConf(same.id.uuidString), atomically: true, encoding: .utf8)
        try "b".write(to: paths.siteBackendConf(edited.id.uuidString), atomically: true, encoding: .utf8)
        let before = supervisor.confSnapshot(for: sites)
        try "b2".write(to: paths.siteBackendConf(edited.id.uuidString), atomically: true, encoding: .utf8)
        try "c".write(to: paths.siteBackendConf(added.id.uuidString), atomically: true, encoding: .utf8)
        XCTAssertEqual(supervisor.changedConfs(since: before, sites: sites), [edited.id, added.id])
    }
}
