import XCTest
@testable import KDWarmKit

final class AppSupportPathsAndPoolTests: XCTestCase {
    private let paths = AppSupportPaths(root: URL(fileURLWithPath: "/tmp/kdwarm-test"))

    func testDirectoryTreeIsRootedUnderAppSupport() {
        XCTAssertTrue(paths.bin.path.hasPrefix(paths.root.path))
        XCTAssertEqual(paths.nginxBinary.lastPathComponent, "nginx")
        XCTAssertEqual(paths.phpFpmBinary.lastPathComponent, "php-fpm")
        XCTAssertEqual(paths.phpFpmSocket("demo").lastPathComponent, "php-fpm-demo.sock")
    }

    func testEnsureDirectoryTreeCreatesAllDirsWithUserOnlyPerms() throws {
        let tmp = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("kdwarm-\(UUID().uuidString)")
        let p = AppSupportPaths(root: tmp)
        defer { try? FileManager.default.removeItem(at: tmp) }

        try p.ensureDirectoryTree()
        for dir in p.allDirectories {
            var isDir: ObjCBool = false
            XCTAssertTrue(FileManager.default.fileExists(atPath: dir.path, isDirectory: &isDir))
            XCTAssertTrue(isDir.boolValue)
            let perms = (try FileManager.default.attributesOfItem(atPath: dir.path)[.posixPermissions] as? Int) ?? -1
            XCTAssertEqual(perms, 0o700, "\(dir.lastPathComponent) must be user-only")
        }
    }

    func testPoolConfigListensOnUnixSocket() {
        let conf = PHPFPMPoolWriter().poolConfig(paths: paths, poolName: "demo", user: "tester")
        XCTAssertTrue(conf.contains("listen = \(paths.phpFpmSocket("demo").path)"))
        XCTAssertTrue(conf.contains("[demo]"))
        XCTAssertTrue(conf.contains("daemonize = no"))
        XCTAssertTrue(conf.contains("user = tester"))
    }

    func testPortPreflightConflictMessageNamesApache() {
        let msg = PortPreflight.conflictMessage(port: 80, process: "httpd")
        XCTAssertTrue(msg.contains("Apache"))
        XCTAssertTrue(msg.contains("80"))
    }

    func testBinaryStagerListsExpectedBinaries() {
        XCTAssertEqual(Set(BinaryStager.binaryNames), ["nginx", "php", "php-fpm"])
    }
}
