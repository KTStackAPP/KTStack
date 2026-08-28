import XCTest
@testable import KTDatabasePlugin

/// Engine-free coverage of statement splitting. A ; inside strings, backtick identifiers or comments
/// must not split; three real statements must produce three ordered statements with correct source ranges.
final class SQLStatementSplitterTests: XCTestCase {
    private func texts(_ sql: String) -> [String] {
        SQLStatementSplitter.split(sql).map(\.sql)
    }

    func testThreeStatementsSplitInOrder() {
        XCTAssertEqual(
            texts("SELECT 1; SELECT 2; SELECT 3"),
            ["SELECT 1", "SELECT 2", "SELECT 3"]
        )
    }

    func testSemicolonInsideSingleQuoteDoesNotSplit() {
        XCTAssertEqual(texts("SELECT 'a;b' AS x"), ["SELECT 'a;b' AS x"])
    }

    func testSemicolonInsideDoubleQuoteDoesNotSplit() {
        XCTAssertEqual(texts("SELECT \"a;b\" AS x"), ["SELECT \"a;b\" AS x"])
    }

    func testSemicolonInsideBacktickIdentifierDoesNotSplit() {
        XCTAssertEqual(texts("SELECT `we;ird` FROM t"), ["SELECT `we;ird` FROM t"])
    }

    func testSemicolonInsideLineCommentDoesNotSplit() {
        XCTAssertEqual(texts("SELECT 1 -- a; b\n"), ["SELECT 1"])
    }

    func testSemicolonInsideHashCommentDoesNotSplit() {
        XCTAssertEqual(texts("SELECT 1 # a; b\n"), ["SELECT 1"])
    }

    func testSemicolonInsideBlockCommentDoesNotSplit() {
        XCTAssertEqual(texts("SELECT 1 /* a; b; c */"), ["SELECT 1"])
    }

    func testEscapedQuoteKeepsStringOpen() {
        XCTAssertEqual(texts("SELECT 'it''s; ok' AS x"), ["SELECT 'it''s; ok' AS x"])
    }

    func testTrailingSemicolonYieldsNoEmptyStatement() {
        XCTAssertEqual(texts("SELECT 1;"), ["SELECT 1"])
    }

    func testEmptyAndWhitespaceOnlySegmentsAreDropped() {
        XCTAssertEqual(texts("SELECT 1;;  ; SELECT 2"), ["SELECT 1", "SELECT 2"])
    }

    func testCommentOnlySegmentIsDropped() {
        XCTAssertEqual(texts("SELECT 1; -- just a comment"), ["SELECT 1"])
    }

    func testBlankInputYieldsNothing() {
        XCTAssertTrue(texts("   \n  ").isEmpty)
    }

    func testRangeMapsBackToSource() {
        let sql = "SELECT 1; SELECT 22"
        let statements = SQLStatementSplitter.split(sql)
        XCTAssertEqual(statements.count, 2)
        let chars = Array(sql)
        for statement in statements {
            XCTAssertEqual(String(chars[statement.range]), statement.sql)
        }
    }

    func testInteriorCommentIsPreserved() {
        let out = texts("SELECT /* keep */ 1")
        XCTAssertEqual(out, ["SELECT /* keep */ 1"])
    }

    func testMultilineStatementsSplit() {
        let sql = """
        UPDATE t SET a = 1 WHERE id = 1;
        DELETE FROM t WHERE id = 2;
        """
        XCTAssertEqual(
            texts(sql),
            ["UPDATE t SET a = 1 WHERE id = 1", "DELETE FROM t WHERE id = 2"]
        )
    }
}
