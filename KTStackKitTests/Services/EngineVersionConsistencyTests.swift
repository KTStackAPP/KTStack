import KTPlatformContracts
import KTStackCore
import XCTest
@testable import KTStackKit

final class EngineVersionConsistencyTests: XCTestCase {
    private var paths: AppSupportPaths!
    private let fm = FileManager.default

    override func setUp() {
        paths = AppSupportPaths(root: URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("kd-consistency-\(UUID().uuidString)", isDirectory: true))
    }

    override func tearDown() {
        try? fm.removeItem(at: paths.root)
    }

    private func install(_ kind: ServiceKind, _ version: String) throws {
        let binary = paths.runtimeDir(kind.rawValue, version).appendingPathComponent(ServiceBinaryCatalog.marker(kind)!)
        try fm.createDirectory(at: binary.deletingLastPathComponent(), withIntermediateDirectories: true)
        fm.createFile(atPath: binary.path, contents: Data(), attributes: [.posixPermissions: 0o755])
    }

    private func setActive(_ kind: ServiceKind, _ version: String) {
        var store = ServiceVersionStore(paths: paths, catalog: ServiceBinaryCatalog(paths: paths))
        store.setActiveVersion(kind, version)
    }

    private func entries(_ dir: URL) -> [String] {
        (try? fm.contentsOfDirectory(atPath: dir.path)) ?? []
    }

    func testStagedInitMovesCompleteDataDirIntoPlace() throws {
        let dataDir = paths.serviceData("mysql", version: "8.4.0")
        try StagedDataDir.initialize(dataDir, marker: "mysql", tool: "mysqld") { staging in
            try fm.createDirectory(at: staging.appendingPathComponent("mysql"), withIntermediateDirectories: true)
        }
        XCTAssertTrue(fm.fileExists(atPath: dataDir.appendingPathComponent("mysql").path))
        XCTAssertEqual(entries(dataDir.deletingLastPathComponent()).filter { $0.contains("initializing") }, [])
    }

    func testFailedInitLeavesNoHalfInitializedDataDir() {
        let dataDir = paths.serviceData("mysql", version: "8.4.0")
        struct Boom: Error {}
        XCTAssertThrowsError(try StagedDataDir.initialize(dataDir, marker: "mysql", tool: "mysqld") { staging in
            try fm.createDirectory(at: staging, withIntermediateDirectories: true)
            try Data("partial".utf8).write(to: staging.appendingPathComponent("ibdata1"))
            throw Boom()
        })
        XCTAssertFalse(fm.fileExists(atPath: dataDir.path))
        XCTAssertEqual(entries(dataDir.deletingLastPathComponent()), [])
    }

    func testLeftoverFilesAreNeverOverwritten() throws {
        let dataDir = paths.serviceData("mysql", version: "8.4.0")
        try fm.createDirectory(at: dataDir, withIntermediateDirectories: true)
        try Data("old".utf8).write(to: dataDir.appendingPathComponent("ibdata1"))
        var populated = false
        XCTAssertThrowsError(try StagedDataDir.initialize(dataDir, marker: "mysql", tool: "mysqld") { _ in populated = true }) {
            XCTAssertTrue($0 is StagedDataDir.LeftoverData)
        }
        XCTAssertFalse(populated)
        XCTAssertEqual(try String(contentsOf: dataDir.appendingPathComponent("ibdata1"), encoding: .utf8), "old")
    }

    func testToolsFollowActiveVersionChangedAfterLaunch() throws {
        try install(.mysql, "8.4.0")
        try install(.mysql, "9.6.0")
        let tools = DatabaseToolsService(paths: paths)
        XCTAssertEqual(tools.activeVersion(.mysql), "9.6.0")

        setActive(.mysql, "8.4.0")

        XCTAssertEqual(tools.activeVersion(.mysql), "8.4.0")
        XCTAssertTrue(try XCTUnwrap(tools.binary(.mysql, "bin/mysqldump")).path.contains("/8.4.0/"))
    }

    func testPostgresRelocationUsesPGVersionNotNewestInstall() throws {
        try install(.postgres, "16.4")
        try install(.postgres, "17.2")
        let flat = paths.serviceData("postgres")
        try fm.createDirectory(at: flat, withIntermediateDirectories: true)
        try Data("16\n".utf8).write(to: flat.appendingPathComponent("PG_VERSION"))

        ServiceDataRelocation.runIfNeeded(paths: paths, catalog: ServiceBinaryCatalog(paths: paths))

        XCTAssertTrue(fm.fileExists(atPath: paths.serviceData("postgres", version: "16.4").appendingPathComponent("PG_VERSION").path))
        XCTAssertFalse(fm.fileExists(atPath: paths.serviceData("postgres", version: "17.2").path))
    }

    func testPostgresRelocationWaitsWhenMatchingMajorIsNotInstalled() throws {
        try install(.postgres, "17.2")
        let flat = paths.serviceData("postgres")
        try fm.createDirectory(at: flat, withIntermediateDirectories: true)
        try Data("15".utf8).write(to: flat.appendingPathComponent("PG_VERSION"))

        ServiceDataRelocation.runIfNeeded(paths: paths, catalog: ServiceBinaryCatalog(paths: paths))

        XCTAssertTrue(fm.fileExists(atPath: flat.appendingPathComponent("PG_VERSION").path))
    }

    func testMySQLRelocationUsesActiveVersion() throws {
        try install(.mysql, "8.4.0")
        try install(.mysql, "9.6.0")
        setActive(.mysql, "8.4.0")
        let flat = paths.serviceData("mysql")
        try fm.createDirectory(at: flat.appendingPathComponent("mysql"), withIntermediateDirectories: true)

        ServiceDataRelocation.runIfNeeded(paths: paths, catalog: ServiceBinaryCatalog(paths: paths))

        XCTAssertTrue(fm.fileExists(atPath: paths.serviceData("mysql", version: "8.4.0").appendingPathComponent("mysql").path))
    }

    func testPreferredSQLKindFallsBackToMariaDB() throws {
        let catalog = ServiceBinaryCatalog(paths: paths)
        XCTAssertNil(SQLFamily.preferredKind(catalog: catalog))
        try install(.mariadb, "11.4.2")
        XCTAssertEqual(SQLFamily.preferredKind(catalog: catalog), .mariadb)
        try install(.mysql, "8.4.0")
        XCTAssertEqual(SQLFamily.preferredKind(catalog: catalog), .mysql)
    }
}
