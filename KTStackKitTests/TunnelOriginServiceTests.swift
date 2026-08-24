import KTStackCore
import XCTest
@testable import KTStackKit

final class TunnelOriginServiceTests: XCTestCase {
    private func tempService() -> (TunnelOriginService, AppSupportPaths, URL) {
        let root = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("ktstack-tunnel-origin-\(UUID().uuidString)")
        let paths = AppSupportPaths(root: root)
        let service = TunnelOriginService(paths: paths, resolveSite: { _ in nil })
        return (service, paths, root)
    }

    func testRemoveAllOriginsDeletesTunnelVhostFiles() throws {
        let (service, paths, root) = tempService()
        defer { try? FileManager.default.removeItem(at: root) }
        try paths.ensureDirectoryTree()
        let stale = paths.vhost("tunnel-\(UUID().uuidString)")
        try "server {}".write(to: stale, atomically: true, encoding: .utf8)

        service.removeAllOrigins(reloadFront: false)

        XCTAssertFalse(FileManager.default.fileExists(atPath: stale.path))
    }

    func testRemoveAllOriginsLeavesNonTunnelVhosts() throws {
        let (service, paths, root) = tempService()
        defer { try? FileManager.default.removeItem(at: root) }
        try paths.ensureDirectoryTree()
        let keep = paths.vhost("app")
        try "server {}".write(to: keep, atomically: true, encoding: .utf8)

        service.removeAllOrigins(reloadFront: false)

        XCTAssertTrue(FileManager.default.fileExists(atPath: keep.path))
    }

    func testStableBasePortIsDeterministicPerUUID() {
        let (service, _, root) = tempService()
        defer { try? FileManager.default.removeItem(at: root) }
        let id = UUID()
        let first = service.stableBasePort(id)
        XCTAssertEqual(first, service.stableBasePort(id))
        XCTAssertGreaterThanOrEqual(first, 41000)
        XCTAssertLessThan(first, 51000)
    }
}
