import KTStackCore
import XCTest
@testable import KTStackKit

final class MySQLAdminClientTests: XCTestCase {
    func testValidateIdentifierAcceptsNormalNames() throws {
        for name in ["app", "my_db", "blog2026", "wp_site"] {
            XCTAssertNoThrow(try MySQLAdminClient.validateIdentifier(name))
        }
    }

    func testValidateIdentifierRejectsDangerousNames() {
        let bad = ["", "-x", "a/b", "a\\b", "a`b", "a'b", "a\"b", "a=b", "a\u{0}b", String(repeating: "a", count: 65)]
        for value in bad {
            XCTAssertThrowsError(try MySQLAdminClient.validateIdentifier(value), value)
        }
    }

    func testQuoteIdentDoublesBackticks() {
        XCTAssertEqual(MySQLAdminClient.quoteIdent("app"), "`app`")
        XCTAssertEqual(MySQLAdminClient.quoteIdent("a`b"), "`a``b`")
    }

    func testDefaultsFileIs0600AndCarriesNoPassword() throws {
        let client = MySQLAdminClient(host: "127.0.0.1", port: 3306)
        let url = try client.writeDefaultsFile()
        defer { try? FileManager.default.removeItem(at: url) }

        let perms = try FileManager.default.attributesOfItem(atPath: url.path)[.posixPermissions] as? Int
        XCTAssertEqual(perms, 0o600)

        let content = try String(contentsOf: url, encoding: .utf8)
        XCTAssertFalse(content.lowercased().contains("password"))
        XCTAssertTrue(content.contains("user=root"))
        XCTAssertTrue(content.contains("ssl-mode=PREFERRED"))
    }

    func testClientNotInstalledWhenNoBinaryResolves() async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("ktstack-empty-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let client = MySQLAdminClient(paths: AppSupportPaths(root: root), systemToolSearchPaths: [])
        do {
            _ = try await client.databaseExists("app")
            XCTFail("expected clientNotInstalled")
        } catch let error as MySQLAdminClient.ClientError {
            XCTAssertEqual(error, .clientNotInstalled)
        }
    }

    func testCreateExistsDropRoundTrip() async throws {
        try XCTSkipUnless(
            ProcessInfo.processInfo.environment["KTSTACK_DB_IT"] == "1",
            "Set KTSTACK_DB_IT=1 with the managed MySQL engine running on :3306."
        )
        try XCTSkipUnless(
            DatabaseToolsService(paths: AppSupportPaths()).isInstalled(.mysql), "MySQL engine not installed."
        )
        let client = MySQLAdminClient()
        let name = "ktstack_admin_\(UUID().uuidString.prefix(8))"
        defer { Task { try? await client.dropDatabase(name) } }

        var exists = try await client.databaseExists(name)
        XCTAssertFalse(exists)
        try await client.createDatabase(name)
        exists = try await client.databaseExists(name)
        XCTAssertTrue(exists)
        try await client.dropDatabase(name)
        exists = try await client.databaseExists(name)
        XCTAssertFalse(exists)
    }
}
