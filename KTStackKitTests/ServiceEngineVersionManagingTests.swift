import KTPlatformContracts
import KTStackCore
import XCTest
@testable import KTStackKit

@MainActor
final class ServiceEngineVersionManagingTests: XCTestCase {
    private func makeManager() throws -> (ServiceManager, AppSupportPaths) {
        let root = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("kd-svceng-\(UUID().uuidString)", isDirectory: true)
        let paths = AppSupportPaths(root: root)
        try paths.ensureDirectoryTree()
        let dns = DNSAutomationService(bundledDnsmasq: URL(fileURLWithPath: "/dev/null"), tld: "test")
        let server = LocalServerController(bundleBinDir: URL(fileURLWithPath: "/dev/null"), paths: paths)
        return (ServiceManager(server: server, dns: dns, paths: paths), paths)
    }

    private func installRedis(_ version: String, _ paths: AppSupportPaths) throws {
        let bin = paths.runtimeBin("redis", version)
        try FileManager.default.createDirectory(at: bin, withIntermediateDirectories: true)
        FileManager.default.createFile(
            atPath: bin.appendingPathComponent("redis-server").path,
            contents: Data(),
            attributes: [.posixPermissions: 0o755]
        )
    }

    func testEngineSnapshotOrderAndRedisMapping() throws {
        let (sut, paths) = try makeManager()
        defer { try? FileManager.default.removeItem(at: paths.config.deletingLastPathComponent()) }
        try installRedis("7.4.2", paths)

        let snapshots = sut.engineSnapshots
        XCTAssertEqual(snapshots.map(\.engine), [.mysql, .postgres, .redis, .mongodb])

        let redis = try XCTUnwrap(snapshots.first { $0.engine == .redis })
        XCTAssertTrue(redis.installed.contains("7.4.2"))
        XCTAssertFalse(redis.available.contains { $0.version == "7.4.2" }) // installed excluded
        XCTAssertTrue(redis.available.contains { $0.version == "7.2.14" })

        // Contract release id must equal the platform ServiceBinaryRelease id for downloadFraction mapping.
        let contractRelease = try XCTUnwrap(redis.available.first { $0.version == "7.2.14" })
        let platformRelease = try XCTUnwrap(sut.availableReleases(.redis).first { $0.version == "7.2.14" })
        XCTAssertEqual(contractRelease.id, platformRelease.id)
    }

    func testSetActiveReflectedInSnapshot() throws {
        let (sut, paths) = try makeManager()
        defer { try? FileManager.default.removeItem(at: paths.config.deletingLastPathComponent()) }
        try installRedis("7.4.2", paths)
        try installRedis("7.2.14", paths)

        try (sut as any ServiceEngineVersionManaging).setActiveVersion(.redis, version: "7.4.2")
        let redis = try XCTUnwrap(sut.engineSnapshots.first { $0.engine == .redis })
        XCTAssertEqual(redis.active, "7.4.2")
        XCTAssertFalse(redis.isRunning)
    }
}
