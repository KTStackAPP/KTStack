import XCTest
@testable import KTDatabasePlugin

/// Engine-free coverage of named-parameter binding: detection outside strings/comments, positional
/// placeholder rewrite without interpolation, missing-value reporting and typed coercion.
final class QueryParameterBinderTests: XCTestCase {
    private let mysql = SQLDialect.forKind(.mysql)
    private let postgres = SQLDialect.forKind(.postgres)

    func testPlaceholdersOrderedAndDeduplicated() {
        XCTAssertEqual(
            QueryParameterBinder.placeholders(in: "SELECT * FROM t WHERE a = :id AND b = :name OR c = :id"),
            ["id", "name"]
        )
    }

    func testIgnoresPlaceholdersInStringsAndComments() {
        XCTAssertTrue(QueryParameterBinder.placeholders(in: "SELECT ':id' -- :name\n").isEmpty)
        XCTAssertTrue(QueryParameterBinder.placeholders(in: "SELECT 1 /* :x */").isEmpty)
    }

    func testIgnoresAssignmentAndCastOperators() {
        // := (gán biến MySQL) và :: (cast) không phải placeholder.
        XCTAssertTrue(QueryParameterBinder.placeholders(in: "SET @x := 1").isEmpty)
        XCTAssertTrue(QueryParameterBinder.placeholders(in: "SELECT 1::int").isEmpty)
    }

    func testBindRewritesToQuestionMarksInOrder() {
        let binding = QueryParameterBinder.bind(
            "SELECT * FROM t WHERE a = :id AND b = :name",
            values: ["id": .int(7), "name": .text("kt")],
            dialect: mysql
        )
        XCTAssertEqual(binding.statement.sql, "SELECT * FROM t WHERE a = ? AND b = ?")
        XCTAssertEqual(binding.statement.binds, [.int(7), .text("kt")])
        XCTAssertTrue(binding.missing.isEmpty)
    }

    func testRepeatedPlaceholderBindsEachOccurrence() {
        let binding = QueryParameterBinder.bind(
            "SELECT :id, :id", values: ["id": .int(3)], dialect: mysql
        )
        XCTAssertEqual(binding.statement.sql, "SELECT ?, ?")
        XCTAssertEqual(binding.statement.binds, [.int(3), .int(3)])
    }

    func testPostgresUsesDollarPlaceholders() {
        let binding = QueryParameterBinder.bind(
            "SELECT * FROM t WHERE a = :id AND b = :name",
            values: ["id": .int(1), "name": .text("x")],
            dialect: postgres
        )
        XCTAssertEqual(binding.statement.sql, "SELECT * FROM t WHERE a = $1 AND b = $2")
    }

    func testMissingValueBindsNullAndIsReported() {
        let binding = QueryParameterBinder.bind(
            "SELECT :id", values: [:], dialect: mysql
        )
        XCTAssertEqual(binding.statement.binds, [.null])
        XCTAssertEqual(binding.missing, ["id"])
    }

    func testDoesNotSplitOrInterpolateValueContainingSql() {
        let binding = QueryParameterBinder.bind(
            "SELECT * FROM t WHERE name = :name",
            values: ["name": .text("'; DROP TABLE t; --")],
            dialect: mysql
        )
        XCTAssertEqual(binding.statement.sql, "SELECT * FROM t WHERE name = ?")
        XCTAssertEqual(binding.statement.binds, [.text("'; DROP TABLE t; --")])
    }

    func testCoerceTypes() {
        XCTAssertEqual(QueryParameterBinder.coerce("42"), .int(42))
        XCTAssertEqual(QueryParameterBinder.coerce("3.14"), .double(3.14))
        XCTAssertEqual(QueryParameterBinder.coerce("null"), .null)
        XCTAssertEqual(QueryParameterBinder.coerce("NULL"), .null)
        XCTAssertEqual(QueryParameterBinder.coerce("hello"), .text("hello"))
        // "10" là int, không phải double dù parse được.
        XCTAssertEqual(QueryParameterBinder.coerce("10"), .int(10))
    }
}
