import XCTest
@testable import KTDatabasePlugin

/// Engine-free tests for EXPLAIN tree parsing and the multi-column degrade-to-raw rule.
final class ExplainPlanParserTests: XCTestCase {
    private func singleColumn(_ text: String, name: String = "EXPLAIN") -> QueryResult {
        QueryResult(columns: [ColumnMeta(name: name)], rows: [[.text(text)]])
    }

    func testMySQLTreeIndentationBuildsHierarchy() {
        let plan = "-> Limit: 1000 row(s)\n    -> Table scan on users"
        let tree = ExplainPlanParser.parse(singleColumn(plan))
        XCTAssertEqual(tree?.count, 1)
        XCTAssertEqual(tree?.first?.text, "Limit: 1000 row(s)")
        XCTAssertEqual(tree?.first?.children.count, 1)
        XCTAssertEqual(tree?.first?.children.first?.text, "Table scan on users")
    }

    func testPostgresIndentedTextBuildsHierarchy() {
        let plan = "Limit  (cost=0.00..1.00)\n  ->  Seq Scan on users  (cost=0.00..1.00)"
        let tree = ExplainPlanParser.parse(singleColumn(plan, name: "QUERY PLAN"))
        XCTAssertEqual(tree?.count, 1)
        XCTAssertEqual(tree?.first?.children.first?.text, "Seq Scan on users  (cost=0.00..1.00)")
    }

    func testMultiColumnDegradesToRaw() {
        let tabular = QueryResult(
            columns: [ColumnMeta(name: "id"), ColumnMeta(name: "select_type")],
            rows: [[.int(1), .text("SIMPLE")]]
        )
        XCTAssertNil(ExplainPlanParser.parse(tabular))
    }

    func testEmptyReturnsNil() {
        XCTAssertNil(ExplainPlanParser.parse(singleColumn("   ")))
    }

    func testThreeLevelNesting() {
        let plan = "-> A\n    -> B\n        -> C"
        let tree = ExplainPlanParser.parse(singleColumn(plan))
        XCTAssertEqual(tree?.first?.text, "A")
        XCTAssertEqual(tree?.first?.children.first?.text, "B")
        XCTAssertEqual(tree?.first?.children.first?.children.first?.text, "C")
    }
}
