import XCTest
@testable import KTDatabasePlugin

final class GridCopySerializerTests: XCTestCase {
    private let serializer = GridCopySerializer(quote: "`")

    private let result = QueryResult(
        columns: [ColumnMeta(name: "id"), ColumnMeta(name: "name"), ColumnMeta(name: "note")],
        rows: [
            [.int(1), .text("Alice"), .null],
            [.int(2), .text("O'Hara"), .text("a,b")],
        ]
    )

    private let allRows = [0, 1]
    private let allColumns = [0, 1, 2]

    func testTSVFlattensNull() {
        let text = serializer.serialize(result, rows: allRows, columns: allColumns, format: .tsv)
        XCTAssertEqual(text, "1\tAlice\t\n2\tO'Hara\ta,b")
    }

    func testCSVQuotesDelimiterAndUsesCRLF() {
        let text = serializer.serialize(result, rows: allRows, columns: allColumns, format: .csv)
        XCTAssertEqual(text, "1,Alice,\r\n2,O'Hara,\"a,b\"")
    }

    func testJSONPreservesNullAndTypes() throws {
        let text = serializer.serialize(result, rows: [0], columns: allColumns, format: .json)
        let data = try XCTUnwrap(text.data(using: .utf8))
        let array = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [[String: Any]])
        XCTAssertEqual(array.count, 1)
        XCTAssertEqual(array[0]["id"] as? Int, 1)
        XCTAssertEqual(array[0]["name"] as? String, "Alice")
        XCTAssertTrue(array[0]["note"] is NSNull)
    }

    func testMarkdownTable() {
        let text = serializer.serialize(result, rows: [0], columns: [0, 1], format: .markdown)
        XCTAssertEqual(text, "| id | name |\n| --- | --- |\n| 1 | Alice |")
    }

    func testSQLInsertLiteralizesValues() {
        let text = serializer.serialize(result, rows: allRows, columns: allColumns, format: .sqlInsert(table: "users"))
        XCTAssertEqual(
            text,
            "INSERT INTO `users` (`id`, `name`, `note`) VALUES\n(1, 'Alice', NULL),\n(2, 'O''Hara', 'a,b');"
        )
    }

    func testSQLUpdateKeyedByColumn() {
        let text = serializer.serialize(result, rows: [1], columns: allColumns, format: .sqlUpdate(table: "users", keyColumns: ["id"]))
        XCTAssertEqual(text, "UPDATE `users` SET `name` = 'O''Hara', `note` = 'a,b' WHERE `id` = 2;")
    }

    func testInList() {
        let text = serializer.serialize(result, rows: allRows, columns: [0], format: .inList)
        XCTAssertEqual(text, "(1, 2)")
    }

    func testOutOfRangeIndicesAreIgnored() {
        let text = serializer.serialize(result, rows: [0, 99], columns: [0], format: .tsv)
        XCTAssertEqual(text, "1")
    }
}
