import XCTest
@testable import KTDatabasePlugin

/// Table/view lifecycle DDL plus the token/expression/view sanitizers the renderer relies on.
final class SQLDialectLifecycleTests: XCTestCase {
    private let d = SQLDialect.forKind(.mysql)

    func testRenameTable() throws {
        XCTAssertEqual(
            try d.renameTable(schema: "app", table: "t", to: "t2"),
            "ALTER TABLE `app`.`t` RENAME TO `app`.`t2`"
        )
    }

    func testTruncateTable() throws {
        XCTAssertEqual(try d.truncateTable(schema: "app", table: "t"), "TRUNCATE TABLE `app`.`t`")
    }

    func testCreateView() throws {
        XCTAssertEqual(
            try d.createView(schema: "app", view: "v", definition: "SELECT id FROM t"),
            "CREATE VIEW `app`.`v` AS SELECT id FROM t"
        )
    }

    func testDropView() throws {
        XCTAssertEqual(try d.dropView(schema: "app", view: "v"), "DROP VIEW `app`.`v`")
    }

    func testCreateViewRejectsNonSelect() {
        XCTAssertThrowsError(try d.createView(schema: "app", view: "v", definition: "DROP TABLE t"))
    }

    func testCreateViewRejectsTerminator() {
        XCTAssertThrowsError(try d.createView(schema: "app", view: "v", definition: "SELECT 1; DROP TABLE t"))
    }

    func testQuoteStringEscapes() throws {
        XCTAssertEqual(try d.quoteString("O'Brien"), "'O''Brien'")
        XCTAssertEqual(try d.quoteString("a\\b"), "'a\\\\b'")
        XCTAssertThrowsError(try d.quoteString("a\u{0}b"))
    }

    func testSanitizeToken() throws {
        XCTAssertEqual(try SQLDialect.sanitizeToken(" utf8mb4 "), "utf8mb4")
        XCTAssertThrowsError(try SQLDialect.sanitizeToken(""))
        XCTAssertThrowsError(try SQLDialect.sanitizeToken("utf8 OR 1=1"))
        XCTAssertThrowsError(try SQLDialect.sanitizeToken("a;b"))
        XCTAssertThrowsError(try SQLDialect.sanitizeToken("a'b"))
    }

    func testSanitizeExpressionAllowsNewlineRejectsTerminator() throws {
        XCTAssertEqual(try SQLDialect.sanitizeExpression("a >= 0\n AND b < 10"), "a >= 0\n AND b < 10")
        XCTAssertThrowsError(try SQLDialect.sanitizeExpression(""))
        XCTAssertThrowsError(try SQLDialect.sanitizeExpression("1=1; DROP TABLE t"))
        XCTAssertThrowsError(try SQLDialect.sanitizeExpression("a\u{0}b"))
    }
}
