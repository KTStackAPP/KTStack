import KTStackCore
import XCTest
@testable import KTDatabasePlugin

@MainActor
final class DDLHistoryGuardTests: XCTestCase {
    private func temporaryPaths() -> AppSupportPaths {
        AppSupportPaths(root: FileManager.default.temporaryDirectory
            .appendingPathComponent("ktstack-history-guard-\(UUID().uuidString)", isDirectory: true))
    }

    func testHistoryRedactsPasswords() throws {
        let store = QueryHistoryStore(paths: temporaryPaths())
        try store.record(sql: "CREATE USER 'app'@'%' IDENTIFIED BY 's3cret!'", connectionLabel: "Local", database: nil)
        try store.record(sql: "ALTER ROLE app WITH PASSWORD 'hunter2'", connectionLabel: "Local", database: nil)
        try store.record(sql: "SET PASSWORD = \"topsecret\"", connectionLabel: "Local", database: nil)

        let joined = store.entries().map(\.sql).joined(separator: "\n")
        XCTAssertFalse(joined.contains("s3cret"))
        XCTAssertFalse(joined.contains("hunter2"))
        XCTAssertFalse(joined.contains("topsecret"))
        XCTAssertTrue(joined.contains("IDENTIFIED BY '***'"))
    }

    func testHistoryFileIsPrivateAndSkipsHugeStatements() throws {
        let paths = temporaryPaths()
        let store = QueryHistoryStore(paths: paths)
        try store.record(sql: "SELECT 1", connectionLabel: "Local", database: nil)
        try store.record(sql: "SELECT '" + String(repeating: "x", count: 70000) + "'", connectionLabel: "Local", database: nil)
        QueryHistoryStore.waitForPendingWrites()

        XCTAssertEqual(store.entries().map(\.sql), ["SELECT 1"])
        let perms = try FileManager.default.attributesOfItem(atPath: paths.queryHistoryFile.path)[.posixPermissions] as? Int
        XCTAssertEqual(perms, 0o600)
        XCTAssertEqual(QueryHistoryStore(paths: paths).limit, 1000)
    }

    func testDestructiveGuardSeesPastLeadingComments() {
        XCTAssertTrue(DestructiveGuard.evaluate("/* cleanup */ DROP TABLE users").isDestructive)
        XCTAssertTrue(DestructiveGuard.evaluate("-- reset\nTRUNCATE orders").isDestructive)
        XCTAssertTrue(DestructiveGuard.evaluate("DELETE FROM t -- WHERE id = 1").isDestructive)
        XCTAssertTrue(DestructiveGuard.evaluate("UPDATE t SET note = 'where'").isDestructive)
        XCTAssertFalse(DestructiveGuard.evaluate("DELETE FROM t WHERE id = 1").isDestructive)
    }

    func testStatementKindUsesSkeletonAndTreatsReadWriteToggleAsWrite() {
        XCTAssertEqual(SQLStatementKind.classify("-- note\nSELECT 1"), .read)
        XCTAssertEqual(SQLStatementKind.classify("/* SELECT */ DELETE FROM t"), .write)
        XCTAssertEqual(SQLStatementKind.classify("SET SESSION TRANSACTION READ WRITE"), .write)
        XCTAssertEqual(SQLStatementKind.classify("SET GLOBAL read_only = 0"), .write)
        XCTAssertEqual(SQLStatementKind.classify("SET default_transaction_read_only = off"), .write)
        XCTAssertEqual(SQLStatementKind.classify("SET NAMES utf8mb4"), .read)
        XCTAssertEqual(SQLStatementKind.classify("WITH x AS (SELECT 'delete') SELECT * FROM x"), .read)
    }
}
