import KTPlatformContracts
import KTStackCore
import XCTest
@testable import KTStackKit

final class DatabaseToolsServiceTests: XCTestCase {
    private func tempRoot() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("ktstack-dbtools-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    func testNothingInstalled() throws {
        let root = try tempRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let tools = DatabaseToolsService(paths: AppSupportPaths(root: root))
        XCTAssertFalse(tools.isInstalled(.mysql))
        XCTAssertFalse(tools.isInstalled(.postgres))
        XCTAssertFalse(tools.isInstalled(.mongodb))
        XCTAssertNil(tools.activeVersion(.mysql))
        XCTAssertFalse(tools.mongoToolsInstalled)
        XCTAssertNil(tools.mongoToolsBinary("bin/mongodump"))
    }

    func testEngineMapsToServiceKindAndResolvesInstalledMarker() throws {
        let root = try tempRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let paths = AppSupportPaths(root: root)
        let bin = paths.runtimeBin("mysql", "9.6.0")
        try FileManager.default.createDirectory(at: bin, withIntermediateDirectories: true)
        let mysqld = bin.appendingPathComponent("mysqld")
        XCTAssertTrue(FileManager.default.createFile(
            atPath: mysqld.path, contents: Data("#!/bin/sh\n".utf8), attributes: [.posixPermissions: 0o755]
        ))

        let tools = DatabaseToolsService(paths: paths)
        XCTAssertTrue(tools.isInstalled(.mysql))
        XCTAssertEqual(tools.activeVersion(.mysql), "9.6.0")
        XCTAssertEqual(tools.binary(.mysql, "bin/mysqld"), mysqld)
        XCTAssertEqual(
            tools.binary(.mysql, "bin/mysql", version: "9.6.0"),
            paths.runtimeDir("mysql", "9.6.0").appendingPathComponent("bin/mysql")
        )
        XCTAssertFalse(tools.isInstalled(.postgres))
    }
}
