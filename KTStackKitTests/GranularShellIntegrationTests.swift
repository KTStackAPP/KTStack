import KTStackCore
import XCTest
@testable import KTStackKit

final class GranularShellIntegrationTests: XCTestCase {
    private var tmp: URL!
    private let fm = FileManager.default

    override func setUpWithError() throws {
        tmp = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("ktstack-granular-tests-\(UUID().uuidString)")
        try fm.createDirectory(at: tmp, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? fm.removeItem(at: tmp)
    }

    private func makeHelper() throws -> URL {
        let helper = tmp.appendingPathComponent("ktstack-resolve")
        try "#!/bin/sh\necho noop\n".write(to: helper, atomically: true, encoding: .utf8)
        try fm.setAttributes([.posixPermissions: 0o755], ofItemAtPath: helper.path)
        return helper
    }

    func testCatalogContainsAllRequiredSuitesAndTools() {
        let suites = ShellToolSuite.allCases
        XCTAssertEqual(suites.count, 6)

        let ktTools = ShellToolCatalog.tools(for: .ktstack)
        XCTAssertEqual(ktTools.map(\.command), ["kt"])
        let phpTools = ShellToolCatalog.tools(for: .php)
        XCTAssertEqual(phpTools.map(\.command), ["php", "composer", "wp"])

        let nodeTools = ShellToolCatalog.tools(for: .node)
        XCTAssertEqual(nodeTools.map(\.command), ["node", "npm", "npx"])

        let mysqlTools = ShellToolCatalog.tools(for: .mysql)
        XCTAssertEqual(mysqlTools.map(\.command), ["mysql", "mysqldump", "mysqladmin"])

        let pgTools = ShellToolCatalog.tools(for: .postgres)
        XCTAssertEqual(pgTools.map(\.command), ["psql", "pg_dump", "createdb", "dropdb"])

        let redisTools = ShellToolCatalog.tools(for: .redis)
        XCTAssertEqual(redisTools.map(\.command), ["redis-cli", "redis-benchmark"])
    }

    func testEnableGeneratesShimsForAllCatalogTools() async throws {
        let home = tmp.appendingPathComponent("home")
        try fm.createDirectory(at: home, withIntermediateDirectories: true)
        let paths = AppSupportPaths(root: tmp.appendingPathComponent("support"))
        let manager = try ShellPathManager(paths: paths, helperSource: makeHelper(), home: home)

        try await manager.enable(provisionComposer: false)

        for tool in ShellToolCatalog.tools {
            let shimUrl = paths.shimBinDir.appendingPathComponent(tool.command)
            XCTAssertTrue(fm.isExecutableFile(atPath: shimUrl.path), "\(tool.command) shim missing or not executable")
        }
    }

    func testGranularToolToggleUpdatesStoreWithoutTouchingRCFile() async throws {
        let home = tmp.appendingPathComponent("home")
        try fm.createDirectory(at: home, withIntermediateDirectories: true)
        let paths = AppSupportPaths(root: tmp.appendingPathComponent("support"))
        let manager = try ShellPathManager(paths: paths, helperSource: makeHelper(), home: home)

        try await manager.enable(provisionComposer: false)

        let zshrc = home.appendingPathComponent(".zshrc")
        let initialModDate = try fm.attributesOfItem(atPath: zshrc.path)[.modificationDate] as? Date

        try manager.setToolEnabled("node", enabled: false)
        XCTAssertFalse(manager.isToolEnabled("node"))
        XCTAssertTrue(manager.isToolEnabled("mysql"))

        let resolver = ShellToolResolver(paths: paths)
        XCTAssertFalse(resolver.isToolEnabled("node"))
        XCTAssertTrue(resolver.isToolEnabled("mysql"))

        let postToggleModDate = try fm.attributesOfItem(atPath: zshrc.path)[.modificationDate] as? Date
        XCTAssertEqual(initialModDate, postToggleModDate)
    }
}
