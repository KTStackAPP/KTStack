import KTStackCore
import XCTest
@testable import KTStackKit

final class MemcachedControllerTests: XCTestCase {
    private func makeController() -> (MemcachedController, URL) {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("ktstack-memcached-\(UUID().uuidString)", isDirectory: true)
        let paths = AppSupportPaths(root: root)
        return (MemcachedController(paths: paths, agents: LaunchAgentManager(paths: paths)), root)
    }

    func testIdentity() {
        let (controller, root) = makeController()
        defer { try? FileManager.default.removeItem(at: root) }
        XCTAssertEqual(controller.kind, .memcached)
        XCTAssertEqual(controller.detail, ":11211")
        XCTAssertEqual(controller.logsURL?.lastPathComponent, "memcached.log")
    }

    func testNotInstalledWithoutBinary() {
        let (controller, root) = makeController()
        defer { try? FileManager.default.removeItem(at: root) }
        XCTAssertFalse(controller.isInstalled)
    }

    func testDefaultPortAndBinaryName() {
        XCTAssertEqual(ServiceKind.memcached.defaultPort, 11211)
        XCTAssertEqual(ServiceKind.memcached.binaryName, "memcached")
        XCTAssertEqual(ServiceKind.memcached.launchdLabel, "com.ktstack.memcached")
    }
}
