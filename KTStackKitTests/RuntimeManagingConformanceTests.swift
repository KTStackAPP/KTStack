import KTPlatformContracts
import KTStackCore
import XCTest
@testable import KTStackKit

@MainActor
final class RuntimeManagingConformanceTests: XCTestCase {
    private func tempPaths() throws -> AppSupportPaths {
        let root = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("kd-rtmanaging-\(UUID().uuidString)", isDirectory: true)
        let paths = AppSupportPaths(root: root)
        try paths.ensureDirectoryTree()
        return paths
    }

    private func installNodeMarker(_ version: String, _ paths: AppSupportPaths) throws {
        let bin = paths.runtimeBin("node", version)
        try FileManager.default.createDirectory(at: bin, withIntermediateDirectories: true)
        FileManager.default.createFile(
            atPath: bin.appendingPathComponent("node").path,
            contents: Data(),
            attributes: [.posixPermissions: 0o755]
        )
    }

    func testStateMapsInstalledRuntimes() throws {
        let paths = try tempPaths()
        defer { try? FileManager.default.removeItem(at: paths.config) }
        try installNodeMarker("22.22.3", paths)
        let manager: any RuntimeManaging = RuntimeManager(paths: paths)
        XCTAssertEqual(manager.state.installed[.node], ["22.22.3"])
    }

    func testStreamYieldsCurrentThenAfterSetDefault() async throws {
        let paths = try tempPaths()
        defer { try? FileManager.default.removeItem(at: paths.config) }
        try installNodeMarker("22.22.3", paths)
        let manager = RuntimeManager(paths: paths)

        let first = expectation(description: "first snapshot")
        let gotDefault = expectation(description: "snapshot after setGlobalDefault")
        let stream = manager.states()
        let consumer = Task { @MainActor in
            var sawFirst = false
            for await snapshot in stream {
                if !sawFirst {
                    sawFirst = true
                    XCTAssertEqual(snapshot.installed[.node], ["22.22.3"])
                    XCTAssertNil(snapshot.defaults[.node])
                    first.fulfill()
                }
                if snapshot.defaults[.node] == "22.22.3" { gotDefault.fulfill(); break }
            }
        }

        await fulfillment(of: [first], timeout: 2)
        manager.setGlobalDefault(.node, "22.22.3")
        await fulfillment(of: [gotDefault], timeout: 2)
        consumer.cancel()
    }

    func testIsEndOfLife() throws {
        let paths = try tempPaths()
        defer { try? FileManager.default.removeItem(at: paths.config) }
        let manager: any RuntimeManaging = RuntimeManager(paths: paths)
        XCTAssertTrue(manager.isEndOfLife(.php, "7.4"))
        XCTAssertFalse(manager.isEndOfLife(.php, "8.4"))
        XCTAssertFalse(manager.isEndOfLife(.node, "22.22.3"))
    }
}
