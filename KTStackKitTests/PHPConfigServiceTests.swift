import KTPlatformContracts
import KTStackCore
import XCTest
@testable import KTStackKit

final class PHPConfigServiceTests: XCTestCase {
    private func tempPaths() throws -> AppSupportPaths {
        let root = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("kd-phpcfg-\(UUID().uuidString)", isDirectory: true)
        let paths = AppSupportPaths(root: root)
        try paths.ensureDirectoryTree()
        return paths
    }

    private actor Counter {
        private(set) var versions: [String] = []
        func record(_ version: String) { versions.append(version) }
    }

    func testSaveIniRollsBackWhenReloadFails() async throws {
        let paths = try tempPaths()
        defer { try? FileManager.default.removeItem(at: paths.config) }
        let store = PHPIniStore(paths: paths)
        try store.write(version: "8.4", contents: "; INITIAL\n")

        let reloads = Counter()
        let service = PHPConfigService(
            paths: paths,
            reloadPool: { version in await reloads.record(version); throw NSError(domain: "test", code: 1) },
            restartPool: { _ in }
        )

        do {
            try await service.saveIni(phpVersion: "8.4", contents: "; NEW\n")
            XCTFail("expected reloadFailedReverted")
        } catch let error as PHPIniSaveError {
            guard case .reloadFailedReverted = error else { return XCTFail("wrong error \(error)") }
        }

        let restored = try store.read(version: "8.4")
        XCTAssertEqual(restored, "; INITIAL\n")
        let count = await reloads.versions.count
        XCTAssertEqual(count, 2) // reload + revert reload
    }

    func testSaveIniReloadsOnceOnSuccess() async throws {
        let paths = try tempPaths()
        defer { try? FileManager.default.removeItem(at: paths.config) }
        let reloads = Counter()
        let service = PHPConfigService(
            paths: paths,
            reloadPool: { version in await reloads.record(version) },
            restartPool: { _ in }
        )
        try await service.saveIni(phpVersion: "8.4", contents: "; OK\n")
        let versions = await reloads.versions
        XCTAssertEqual(versions, ["8.4"])
        XCTAssertEqual(try service.readIni(phpVersion: "8.4"), "; OK\n")
    }

    func testUninstallExtensionRestartsPool() async throws {
        let paths = try tempPaths()
        defer { try? FileManager.default.removeItem(at: paths.config) }
        let restarts = Counter()
        let service = PHPConfigService(
            paths: paths,
            reloadPool: { _ in },
            restartPool: { version in await restarts.record(version) }
        )
        try await service.uninstallExtension("redis", phpVersion: "8.3")
        let versions = await restarts.versions
        XCTAssertEqual(versions, ["8.3"])
    }

    func testExtensionsExcludeXdebugOptionalFirst() async throws {
        let paths = try tempPaths()
        defer { try? FileManager.default.removeItem(at: paths.config) }
        let service = PHPConfigService(paths: paths, reloadPool: { _ in }, restartPool: { _ in })
        let entries = await service.extensions(phpVersion: "8.4")
        XCTAssertFalse(entries.contains { $0.ext.id == "xdebug" })
        XCTAssertFalse(entries.isEmpty)
        // Optional (non-built-in) extensions sort before built-in ones.
        if let firstBuiltIn = entries.firstIndex(where: { $0.ext.isBuiltIn }) {
            XCTAssertFalse(entries[..<firstBuiltIn].contains { $0.ext.isBuiltIn })
        }
    }

    func testXdebugClientPort() {
        let paths = try? tempPaths()
        let service = PHPConfigService(paths: paths ?? AppSupportPaths(), reloadPool: { _ in }, restartPool: { _ in })
        XCTAssertEqual(service.xdebugClientPort, 9003)
    }
}
