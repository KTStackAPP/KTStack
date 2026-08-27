import KTStackCore
import XCTest
@testable import KTStackKit

final class MySQLFlavorTests: XCTestCase {
    func testFlavorKindAndServerPath() {
        XCTAssertEqual(MySQLFlavor.mysql.kind, .mysql)
        XCTAssertEqual(MySQLFlavor.mariadb.kind, .mariadb)
        XCTAssertEqual(MySQLFlavor.mysql.serverRelPath, "bin/mysqld")
        XCTAssertEqual(MySQLFlavor.mariadb.serverRelPath, "bin/mariadbd")
    }

    func testOnlyMariaDBNeedsBasedir() {
        XCTAssertFalse(MySQLFlavor.mysql.needsBasedir)
        XCTAssertTrue(MySQLFlavor.mariadb.needsBasedir)
    }

    func testMariaDBControllerReportsMariaDBKind() {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("ktstack-mariadb-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let paths = AppSupportPaths(root: root)
        let controller = MySQLController(
            paths: paths, agents: LaunchAgentManager(paths: paths), flavor: .mariadb
        )
        XCTAssertEqual(controller.kind, .mariadb)
        XCTAssertEqual(controller.detail, ":3306")
        XCTAssertFalse(controller.isInstalled) // no binary staged
        XCTAssertEqual(controller.logsURL?.lastPathComponent, "mariadb.log")
    }
}
