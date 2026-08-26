import KTPlatformContracts
import KTStackCore
import XCTest
@testable import KTStackKit

final class AppSupportPathsAndPoolTests: XCTestCase {
    private let paths = AppSupportPaths(root: URL(fileURLWithPath: "/tmp/ktstack-test"))

    func testDirectoryTreeIsRootedUnderAppSupport() {
        XCTAssertTrue(paths.bin.path.hasPrefix(paths.root.path))
        XCTAssertEqual(paths.nginxBinary.lastPathComponent, "nginx")
        XCTAssertTrue(paths.phpFpmBinary(version: "8.4").path.hasSuffix("runtimes/php/8.4/bin/php-fpm"))
        XCTAssertEqual(paths.phpFpmSocket("demo").lastPathComponent, "php-fpm-demo.sock")
    }

    func testEnsureDirectoryTreeCreatesAllDirsWithUserOnlyPerms() throws {
        let tmp = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("ktstack-\(UUID().uuidString)")
        let p = AppSupportPaths(root: tmp)
        defer { try? FileManager.default.removeItem(at: tmp) }

        try p.ensureDirectoryTree()
        for dir in p.allDirectories {
            var isDir: ObjCBool = false
            XCTAssertTrue(FileManager.default.fileExists(atPath: dir.path, isDirectory: &isDir))
            XCTAssertTrue(isDir.boolValue)
            let perms = try (FileManager.default.attributesOfItem(atPath: dir.path)[.posixPermissions] as? Int) ?? -1
            XCTAssertEqual(perms, 0o700, "\(dir.lastPathComponent) must be user-only")
        }
    }

    func testPoolConfigListensOnUnixSocket() throws {
        let conf = try PHPFPMPoolWriter().poolConfig(paths: paths, poolName: "demo", user: "tester")
        XCTAssertTrue(conf.contains("listen = \(paths.phpFpmSocket("demo").path)"))
        XCTAssertTrue(conf.contains("[demo]"))
        XCTAssertTrue(conf.contains("daemonize = no"))
        XCTAssertTrue(conf.contains("user = tester"))
    }

    func testPoolConfigRoutesLocalhostMySQLToBundledSocket() throws {
        let conf = try PHPFPMPoolWriter().poolConfig(paths: paths, poolName: "8.4", user: "tester")
        let sock = paths.serviceSocket("mysql").path
        // localhost DB connections must reach the bundled MySQL socket (Laragon-style), for both
        // mysqli (WordPress) and pdo_mysql (Laravel).
        XCTAssertTrue(conf.contains("php_value[mysqli.default_socket] = \(sock)"))
        XCTAssertTrue(conf.contains("php_value[pdo_mysql.default_socket] = \(sock)"))
        // The legacy ext/mysql directive was removed in PHP 7 — setting it makes php-fpm log
        // "Unable to set php_value 'mysql.default_socket'" on every worker. Must not be emitted.
        XCTAssertFalse(conf.contains("php_value[mysql.default_socket]"))
    }

    func testPoolConfigShellEscapesMailpitPathWithSpaces() throws {
        let spaced = AppSupportPaths(root: URL(fileURLWithPath: "/tmp/KTStack Test"))
        let conf = try PHPFPMPoolWriter().poolConfig(paths: spaced, poolName: "8.4", user: "tester")
        XCTAssertTrue(conf.contains(
            "php_admin_value[sendmail_path] = /tmp/KTStack\\ Test/bin/mailpit sendmail -S 127.0.0.1:1025"
        ))
        XCTAssertFalse(conf.contains("'/tmp/KTStack Test/bin/mailpit'"))
    }

    func testPoolConfigRejectsLineBreakingMailpitPaths() {
        // NUL is covered by the writer's guard but can't be driven through here: URL(fileURLWithPath:)
        // truncates at the NUL, so it never reaches poolConfig as a path byte.
        for scalar in ["\n", "\r"] {
            let invalid = AppSupportPaths(root: URL(fileURLWithPath: "/tmp/KTStack\(scalar)Test"))
            XCTAssertThrowsError(
                try PHPFPMPoolWriter().poolConfig(paths: invalid, poolName: "8.4", user: "tester")
            ) { error in
                XCTAssertEqual(error as? PHPFPMPoolWriterError, .invalidSendmailPath)
                XCTAssertEqual(
                    error.localizedDescription,
                    "The Mailpit executable path contains a line break or null byte and cannot be written safely to PHP-FPM configuration."
                )
            }
        }
    }

    func testDefaultPoolConfigMatchesLegacyProcessManagerBlock() throws {
        let conf = try PHPFPMPoolWriter().poolConfig(paths: paths, poolName: "8.4", user: "tester")
        let expected = """
        pm = dynamic
        pm.max_children = 5
        pm.start_servers = 2
        pm.min_spare_servers = 1
        pm.max_spare_servers = 3
        pm.max_requests = 500
        """
        XCTAssertTrue(conf.contains(expected))
        XCTAssertFalse(conf.contains("pm.process_idle_timeout"))
        XCTAssertFalse(conf.contains("request_terminate_timeout"))
    }

    func testStaticPoolConfigOmitsSpareAndStartServers() throws {
        var settings = PHPPoolSettings.default
        settings.processManager = .static
        settings.maxChildren = 8
        let conf = try PHPFPMPoolWriter().poolConfig(
            paths: paths, poolName: "8.4", user: "tester", settings: settings
        )
        XCTAssertTrue(conf.contains("pm = static"))
        XCTAssertTrue(conf.contains("pm.max_children = 8"))
        XCTAssertTrue(conf.contains("pm.max_requests = 500"))
        XCTAssertFalse(conf.contains("pm.start_servers"))
        XCTAssertFalse(conf.contains("pm.min_spare_servers"))
        XCTAssertFalse(conf.contains("pm.process_idle_timeout"))
    }

    func testOndemandPoolConfigEmitsIdleTimeout() throws {
        var settings = PHPPoolSettings.default
        settings.processManager = .ondemand
        settings.processIdleTimeout = 30
        let conf = try PHPFPMPoolWriter().poolConfig(
            paths: paths, poolName: "8.4", user: "tester", settings: settings
        )
        XCTAssertTrue(conf.contains("pm = ondemand"))
        XCTAssertTrue(conf.contains("pm.process_idle_timeout = 30s"))
        XCTAssertFalse(conf.contains("pm.start_servers"))
    }

    func testRequestTerminateTimeoutEmittedOnlyWhenPositive() throws {
        var settings = PHPPoolSettings.default
        settings.requestTerminateTimeout = 60
        let conf = try PHPFPMPoolWriter().poolConfig(
            paths: paths, poolName: "8.4", user: "tester", settings: settings
        )
        XCTAssertTrue(conf.contains("request_terminate_timeout = 60s"))
    }

    func testPortPreflightConflictMessageNamesApache() {
        let msg = PortPreflight.conflictMessage(port: 80, process: "httpd")
        XCTAssertTrue(msg.contains("Apache"))
        XCTAssertTrue(msg.contains("80"))
    }

    func testBinaryStagerListsExpectedBinaries() {
        // PHP is staged into the runtimes layout, not bin/ — bin/ holds only nginx/dnsmasq/mkcert.
        XCTAssertEqual(Set(BinaryStager.binBinaries), ["nginx", "dnsmasq", "mkcert"])
    }
}
