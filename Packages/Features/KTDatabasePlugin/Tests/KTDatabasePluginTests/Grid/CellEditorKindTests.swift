import XCTest
@testable import KTDatabasePlugin

final class CellEditorKindTests: XCTestCase {
    private func column(_ type: String, nullable: Bool = true) -> ColumnInfo {
        ColumnInfo(name: "c", dataType: type, isNullable: nullable, isPrimaryKey: false)
    }

    func testKindDetection() {
        XCTAssertEqual(CellEditorKind.forColumn(column("tinyint(1)")), .bool)
        XCTAssertEqual(CellEditorKind.forColumn(column("boolean")), .bool)
        XCTAssertEqual(CellEditorKind.forColumn(column("int unsigned")), .number)
        XCTAssertEqual(CellEditorKind.forColumn(column("decimal(10,2)")), .number)
        XCTAssertEqual(CellEditorKind.forColumn(column("date")), .date)
        XCTAssertEqual(CellEditorKind.forColumn(column("datetime")), .datetime)
        XCTAssertEqual(CellEditorKind.forColumn(column("timestamp")), .datetime)
        XCTAssertEqual(CellEditorKind.forColumn(column("time")), .time)
        XCTAssertEqual(CellEditorKind.forColumn(column("json")), .json)
        XCTAssertEqual(CellEditorKind.forColumn(column("longblob")), .binary)
        XCTAssertEqual(CellEditorKind.forColumn(column("varbinary(16)")), .binary)
        XCTAssertEqual(CellEditorKind.forColumn(column("varchar(255)")), .text)
    }

    func testEnumAndSetMembersParsed() {
        XCTAssertEqual(
            CellEditorKind.forColumn(column("enum('active','inactive','pending')")),
            .enumeration(["active", "inactive", "pending"])
        )
        XCTAssertEqual(
            CellEditorKind.forColumn(column("set('a','b')")),
            .setMembership(["a", "b"])
        )
    }

    func testEnumMemberWithEscapedQuote() {
        XCTAssertEqual(
            CellEditorKind.forColumn(column("enum('O''Hara','x')")),
            .enumeration(["O'Hara", "x"])
        )
    }

    func testCoerceEmptyOnNullableBecomesNull() throws {
        let cell = try CellCoercion.cell(for: .value(""), column: column("varchar(5)", nullable: true), kind: .text)
        XCTAssertEqual(cell, .null)
    }

    func testCoerceEmptyOnNotNullBecomesEmptyText() throws {
        let cell = try CellCoercion.cell(for: .value(""), column: column("varchar(5)", nullable: false), kind: .text)
        XCTAssertEqual(cell, .text(""))
    }

    func testCoerceNumberAndBool() throws {
        XCTAssertEqual(try CellCoercion.cell(for: .value("42"), column: column("int"), kind: .number), .int(42))
        XCTAssertEqual(try CellCoercion.cell(for: .value("3.5"), column: column("double"), kind: .number), .double(3.5))
        XCTAssertEqual(try CellCoercion.cell(for: .value("true"), column: column("tinyint(1)"), kind: .bool), .bool(true))
        XCTAssertEqual(try CellCoercion.cell(for: .value("0"), column: column("tinyint(1)"), kind: .bool), .bool(false))
    }

    func testNullOnNotNullColumnThrows() {
        XCTAssertThrowsError(
            try CellCoercion.cell(for: .null, column: column("int", nullable: false), kind: .number)
        ) { error in
            XCTAssertEqual(error as? CellCoercionError, .notNullable)
        }
    }

    func testEnumRejectsUnknownMember() {
        XCTAssertThrowsError(
            try CellCoercion.cell(for: .value("nope"), column: column("enum('a')"), kind: .enumeration(["a"]))
        ) { error in
            XCTAssertEqual(error as? CellCoercionError, .notInEnum("nope"))
        }
    }

    func testSetRejectsUnknownMembers() {
        XCTAssertThrowsError(
            try CellCoercion.cell(for: .value("a,bad"), column: column("set('a','b')"), kind: .setMembership(["a", "b"]))
        ) { error in
            XCTAssertEqual(error as? CellCoercionError, .invalidSetMembers(["bad"]))
        }
    }

    func testSetJoinsValidMembers() throws {
        let cell = try CellCoercion.cell(
            for: .value("a, b"), column: column("set('a','b')"), kind: .setMembership(["a", "b"])
        )
        XCTAssertEqual(cell, .text("a,b"))
    }

    func testNowFormatsByKind() {
        let date = Date(timeIntervalSince1970: 0)
        let utc = TimeZone(identifier: "UTC")!
        XCTAssertEqual(CellCoercion.timestampString(kind: .date, date: date, timeZone: utc), "1970-01-01")
        XCTAssertEqual(CellCoercion.timestampString(kind: .datetime, date: date, timeZone: utc), "1970-01-01 00:00:00")
        XCTAssertEqual(CellCoercion.timestampString(kind: .time, date: date, timeZone: utc), "00:00:00")
    }
}
