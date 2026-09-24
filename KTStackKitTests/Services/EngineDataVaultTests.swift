import KTStackCore
import XCTest
@testable import KTStackKit

final class EngineDataVaultTests: XCTestCase {
    private var root: URL!
    private var paths: AppSupportPaths!
    private var vault: EngineDataVault!

    override func setUpWithError() throws {
        root = FileManager.default.temporaryDirectory.appendingPathComponent("kt-vault-\(UUID().uuidString)", isDirectory: true)
        paths = AppSupportPaths(root: root)
        vault = EngineDataVault(paths: paths)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: root)
    }

    @discardableResult
    private func seed(_ service: String, _ version: String, file: String = "ibdata1", bytes: Int = 1024) throws -> URL {
        let dir = paths.serviceData(service, version: version)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        try Data(repeating: 7, count: bytes).write(to: dir.appendingPathComponent(file))
        return dir
    }

    func testRetireMovesDataUnderRemovedWithTimestamp() throws {
        try seed("mysql", "5.7")
        let now = Date(timeIntervalSince1970: 1_790_000_000)
        let kept = try XCTUnwrap(try vault.retire(service: "mysql", version: "5.7", now: now))
        XCTAssertFalse(FileManager.default.fileExists(atPath: paths.serviceData("mysql", version: "5.7").path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: kept.appendingPathComponent("ibdata1").path))
        XCTAssertEqual(kept.deletingLastPathComponent().lastPathComponent, ".removed")
        XCTAssertEqual(kept.lastPathComponent, "5.7-\(RetiredDataName.stamp(now))")
    }

    func testRetireWithoutDataReturnsNil() throws {
        XCTAssertNil(try vault.retire(service: "redis", version: "7.2.0"))
    }

    func testRetireTwiceInSameSecondKeepsBoth() throws {
        let now = Date(timeIntervalSince1970: 1_790_000_000)
        try seed("redis", "7.2.0")
        let first = try XCTUnwrap(try vault.retire(service: "redis", version: "7.2.0", now: now))
        try seed("redis", "7.2.0")
        let second = try XCTUnwrap(try vault.retire(service: "redis", version: "7.2.0", now: now))
        XCTAssertNotEqual(first, second)
        XCTAssertEqual(vault.retired(service: "redis").count, 2)
    }

    func testRetiredListsNewestFirstAndIgnoresStrangers() throws {
        try seed("postgres", "15")
        _ = try vault.retire(service: "postgres", version: "15", now: Date(timeIntervalSince1970: 1_700_000_000))
        try seed("postgres", "16")
        _ = try vault.retire(service: "postgres", version: "16", now: Date(timeIntervalSince1970: 1_800_000_000))
        try FileManager.default.createDirectory(
            at: vault.removedRoot(service: "postgres").appendingPathComponent("not-kept-data"),
            withIntermediateDirectories: true
        )
        XCTAssertEqual(vault.retired(service: "postgres").map(\.version), ["16", "15"])
    }

    func testRestoreMovesDataBack() throws {
        try seed("mysql", "8.0")
        _ = try vault.retire(service: "mysql", version: "8.0")
        let item = try XCTUnwrap(vault.retired(service: "mysql").first)
        try FileManager.default.createDirectory(at: paths.serviceData("mysql", version: "8.0"), withIntermediateDirectories: true)
        try vault.restore(item)
        XCTAssertTrue(FileManager.default.fileExists(atPath: paths.serviceData("mysql", version: "8.0").appendingPathComponent("ibdata1").path))
        XCTAssertTrue(vault.retired(service: "mysql").isEmpty)
    }

    func testRestoreRefusesToOverwriteLiveData() throws {
        try seed("mysql", "8.0")
        _ = try vault.retire(service: "mysql", version: "8.0")
        let item = try XCTUnwrap(vault.retired(service: "mysql").first)
        try seed("mysql", "8.0", file: "fresh")
        XCTAssertThrowsError(try vault.restore(item))
        XCTAssertTrue(FileManager.default.fileExists(atPath: item.url.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: paths.serviceData("mysql", version: "8.0").appendingPathComponent("fresh").path))
    }

    func testTrashAndRestoreRejectPathsOutsideRemoved() throws {
        let live = try seed("mysql", "8.0")
        let forged = RetiredEngineData(service: "mysql", version: "8.0", url: live, removedAt: Date())
        XCTAssertThrowsError(try vault.trash(forged))
        XCTAssertThrowsError(try vault.restore(forged))
        XCTAssertTrue(FileManager.default.fileExists(atPath: live.path))
    }

    func testSizeCountsFiles() throws {
        let dir = try seed("redis", "7.4.2", bytes: 64 * 1024)
        XCTAssertGreaterThanOrEqual(EngineDataVault.size(of: dir), 64 * 1024)
    }

    func testRetiredNameRoundTrips() throws {
        let now = Date(timeIntervalSince1970: 1_790_000_000)
        let parsed = try XCTUnwrap(RetiredDataName.parse("8.0.36-\(RetiredDataName.stamp(now))-3"))
        XCTAssertEqual(parsed.version, "8.0.36")
        XCTAssertEqual(parsed.removedAt, now)
        XCTAssertNil(RetiredDataName.parse("8.0.36"))
    }

    @MainActor
    func testUninstallRefusesWhileJobIsLoaded() async throws {
        let dns = DNSAutomationService(bundledDnsmasq: URL(fileURLWithPath: "/dev/null"), tld: "test")
        let server = LocalServerController(bundleBinDir: URL(fileURLWithPath: "/dev/null"), paths: paths)
        let sut = ServiceManager(server: server, dns: dns, paths: paths)
        for version in ["7.2.0", "7.4.2"] {
            try FileManager.default.createDirectory(at: paths.runtimeBin("redis", version), withIntermediateDirectories: true)
            FileManager.default.createFile(atPath: paths.runtimeBin("redis", version).appendingPathComponent("redis-server").path, contents: Data())
        }
        try seed("redis", "7.2.0")
        try sut.setActiveVersion(ServiceKind.redis, version: "7.4.2")
        sut.jobLoadedProbe = { $0 == ServiceKind.redis.launchdLabel }
        do {
            _ = try await sut.uninstall(kind: .redis, version: "7.2.0")
            XCTFail("a loaded launchd job must block uninstall")
        } catch {
            XCTAssertTrue(error is ServiceVersionError)
        }
        XCTAssertTrue(FileManager.default.fileExists(atPath: paths.runtimeDir("redis", "7.2.0").path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: paths.serviceData("redis", version: "7.2.0").appendingPathComponent("ibdata1").path))
    }
}
