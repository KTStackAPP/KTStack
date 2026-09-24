import KTStackCore
import XCTest
@testable import KTStackKit

final class IPCDispatcherTests: XCTestCase {
    private let offline = KTIPCCommandDispatcher(serverProvider: { nil }, servicesProvider: { nil })

    func testBackupIsAnExplicitError() async {
        let response = await offline.dispatch(KTIPCRequest(id: "1", method: "db.backup", params: ["database": "shop"]))
        XCTAssertFalse(response.success)
        XCTAssertEqual(response.error, KTIPCCommandDispatcher.backupUnavailable)
    }

    func testLogSourceOutsideTheCatalogIsRejected() async {
        for source in ["../../../etc/passwd", "/etc/hosts", "front-error"] {
            let response = await offline.dispatch(KTIPCRequest(id: "2", method: "logs.recent", params: ["source": source]))
            XCTAssertFalse(response.success, source)
            XCTAssertTrue(response.error?.contains("nginx-error") == true, response.error ?? "")
        }
    }

    func testInvalidServiceNameListsValidOnes() async {
        let response = await offline.dispatch(KTIPCRequest(id: "3", method: "services.stop", params: ["service": "apache2"]))
        XCTAssertFalse(response.success)
        XCTAssertTrue(response.error?.contains("mysql") == true)
    }

    @MainActor
    func testSwitchPHPRejectsVersionThatIsNotInstalled() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("kt-ipc-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let paths = AppSupportPaths(root: root.appendingPathComponent("app", isDirectory: true))
        try paths.ensureDirectoryTree()
        let folder = root.appendingPathComponent("shop/public", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        try "<?php".write(to: folder.appendingPathComponent("index.php"), atomically: true, encoding: .utf8)
        let server = LocalServerController(bundleBinDir: URL(fileURLWithPath: "/dev/null"), paths: paths)
        let site = try server.registry.add(folder: folder.deletingLastPathComponent())
        let dispatcher = KTIPCCommandDispatcher(serverProvider: { server }, servicesProvider: { nil })

        let response = await dispatcher.dispatch(
            KTIPCRequest(id: "4", method: "sites.switch_php", params: ["domain": site.domain, "version": "9.9"])
        )
        XCTAssertFalse(response.success)
        XCTAssertTrue(response.error?.contains("not installed") == true, response.error ?? "")
        XCTAssertNotEqual(server.registry.sites.first?.phpVersion, "9.9")
    }
}
