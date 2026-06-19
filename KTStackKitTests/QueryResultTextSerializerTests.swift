import XCTest
@testable import KTStackKit

final class QueryResultTextSerializerTests: XCTestCase {
    private func result(columns: [String], rows: [[Cell]]) -> QueryResult {
        QueryResult(columns: columns.map { ColumnMeta(name: $0) }, rows: rows)
    }

    func testCSVIncludesHeaderRowByDefault() {
        let r = result(columns: ["id", "name"], rows: [[.int(1), .text("Ann")]])
        XCTAssertEqual(QueryResultTextSerializer.csv(r), "id,name\r\n1,Ann")
    }

    func testCSVQuotesFieldWithComma() {
        let r = result(columns: ["v"], rows: [[.text("a,b")]])
        XCTAssertEqual(QueryResultTextSerializer.csv(r, includeHeaders: false), "\"a,b\"")
    }

    func testCSVEscapesEmbeddedQuote() {
        let r = result(columns: ["v"], rows: [[.text("say \"hi\"")]])
        XCTAssertEqual(QueryResultTextSerializer.csv(r, includeHeaders: false), "\"say \"\"hi\"\"\"")
    }

    func testCSVQuotesFieldWithNewline() {
        let r = result(columns: ["v"], rows: [[.text("line1\nline2")]])
        XCTAssertEqual(QueryResultTextSerializer.csv(r, includeHeaders: false), "\"line1\nline2\"")
    }

    func testPlainFieldIsNotQuoted() {
        let r = result(columns: ["v"], rows: [[.text("plain")]])
        XCTAssertEqual(QueryResultTextSerializer.csv(r, includeHeaders: false), "plain")
    }

    func testNullMapsToEmptyField() {
        let r = result(columns: ["a", "b"], rows: [[.null, .text("x")]])
        XCTAssertEqual(QueryResultTextSerializer.csv(r, includeHeaders: false), ",x")
    }

    func testBoolMapsToOneAndZero() {
        let r = result(columns: ["a", "b"], rows: [[.bool(true), .bool(false)]])
        XCTAssertEqual(QueryResultTextSerializer.csv(r, includeHeaders: false), "1,0")
    }

    func testIntAndDoubleUseDisplayText() {
        let r = result(columns: ["i", "d"], rows: [[.int(42), .double(3.5)]])
        XCTAssertEqual(QueryResultTextSerializer.csv(r, includeHeaders: false), "42,3.5")
    }

    func testBlobRendersByteCountPlaceholder() {
        let r = result(columns: ["b"], rows: [[.blob(Data(count: 3))]])
        XCTAssertEqual(QueryResultTextSerializer.csv(r, includeHeaders: false), "[3 bytes]")
    }

    func testTSVUsesTabDelimiterAndNoHeaderByDefault() {
        let r = result(columns: ["id", "name"], rows: [[.int(1), .text("Ann")]])
        XCTAssertEqual(QueryResultTextSerializer.tsv(r), "1\tAnn")
    }

    func testTSVQuotesFieldContainingTab() {
        let r = result(columns: ["v"], rows: [[.text("a\tb")]])
        XCTAssertEqual(QueryResultTextSerializer.tsv(r), "\"a\tb\"")
    }

    func testRowSubsetSelectsOnlyGivenIndices() {
        let r = result(columns: ["v"], rows: [[.text("r0")], [.text("r1")], [.text("r2")]])
        XCTAssertEqual(QueryResultTextSerializer.csv(r, rows: [0, 2], includeHeaders: false), "r0\r\nr2")
    }

    func testOutOfRangeIndicesAreIgnored() {
        let r = result(columns: ["v"], rows: [[.text("r0")]])
        XCTAssertEqual(QueryResultTextSerializer.csv(r, rows: [0, 9], includeHeaders: false), "r0")
    }

    func testMultipleRowsJoinWithCRLF() {
        let r = result(columns: ["v"], rows: [[.text("a")], [.text("b")]])
        XCTAssertEqual(QueryResultTextSerializer.csv(r, includeHeaders: false), "a\r\nb")
    }

    func testUnicodePreservedRoundTrip() {
        let r = result(columns: ["tên"], rows: [[.text("Nguyễn Khôi")]])
        XCTAssertEqual(QueryResultTextSerializer.csv(r), "tên\r\nNguyễn Khôi")
    }
}
