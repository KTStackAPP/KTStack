import XCTest
@testable import KTDatabasePlugin

/// Engine-free tests for the local SQL formatter: meaning-safe reflow, keyword casing, clause
/// line breaks, and verbatim preservation of strings, comments and operator spelling.
final class SQLFormatterTests: XCTestCase {
    private let keywords = SQLKeywords.forKind(.mysql)

    func testClauseKeywordsBreakOntoNewLines() {
        let out = SQLFormatter.format("select * from users where id = 1 order by name", keywords: keywords)
        XCTAssertEqual(out, "SELECT *\nFROM users\nWHERE id = 1\nORDER BY name")
    }

    func testKeywordsUppercasedButIdentifiersUntouched() {
        let out = SQLFormatter.format("select Id, Name from Users", keywords: keywords)
        XCTAssertEqual(out, "SELECT Id, Name\nFROM Users")
    }

    func testStringLiteralPreservedVerbatim() {
        let out = SQLFormatter.format("select 'from where SELECT' as x", keywords: keywords)
        XCTAssertEqual(out, "SELECT 'from where SELECT' AS x")
    }

    func testOperatorSpellingAndMemberAccessPreserved() {
        let out = SQLFormatter.format("select a.b where x>=1 and y = 2", keywords: keywords)
        XCTAssertEqual(out, "SELECT a.b\nWHERE x>=1 AND y = 2")
    }

    func testCommaSpacingNormalized() {
        let out = SQLFormatter.format("select a ,b,  c from t", keywords: keywords)
        XCTAssertEqual(out, "SELECT a, b, c\nFROM t")
    }

    func testLineCommentForcesNextTokenToNewLine() {
        // Nếu token sau -- comment nằm cùng dòng thì bị nuốt vào comment: phải xuống dòng.
        let out = SQLFormatter.format("select 1 -- note\nfrom t", keywords: keywords)
        XCTAssertTrue(out.contains("-- note\n"), out)
        XCTAssertTrue(out.hasSuffix("FROM t"), out)
    }

    func testJoinClausesBreakWithoutDoubleBreak() {
        let out = SQLFormatter.format("select * from a left join b on a.id = b.id", keywords: keywords)
        XCTAssertEqual(out, "SELECT *\nFROM a\nLEFT JOIN b\nON a.id = b.id")
    }

    func testSubqueryKeywordsStayInlineInsideParens() {
        let out = SQLFormatter.format("select * from (select 1) t", keywords: keywords)
        XCTAssertEqual(out, "SELECT *\nFROM (SELECT 1) t")
    }

    func testMultipleStatementsSeparatedBySemicolon() {
        let out = SQLFormatter.format("select 1; select 2", keywords: keywords)
        XCTAssertEqual(out, "SELECT 1;\n\nSELECT 2")
    }

    func testTrailingSemicolonPreserved() {
        XCTAssertEqual(SQLFormatter.format("select 1;", keywords: keywords), "SELECT 1;")
        XCTAssertEqual(SQLFormatter.format("select 1", keywords: keywords), "SELECT 1")
    }

    func testIdempotent() {
        let once = SQLFormatter.format("select a,b from t where a=1 order by b", keywords: keywords)
        XCTAssertEqual(SQLFormatter.format(once, keywords: keywords), once)
    }

    func testBlankInputReturnsUnchanged() {
        XCTAssertEqual(SQLFormatter.format("   ", keywords: keywords), "   ")
        XCTAssertEqual(SQLFormatter.format("-- only a comment", keywords: keywords), "-- only a comment")
    }
}
