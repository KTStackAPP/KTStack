import MongoKitten
import NIOCore
import XCTest
@testable import KTDatabasePlugin

final class MongoRawBSONTests: XCTestCase {
    static let oneDecimalDocument: [UInt8] = [
        0x18, 0, 0, 0, 0x13, 0x70, 0,
        1, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0x40, 0x30,
        0,
    ]

    func testDecimalIsReadFromTheRawBytes() {
        let document = Document(bytes: Self.oneDecimalDocument)
        XCTAssertEqual(MongoRawBSON.decimals(in: document)["p"]?.description, "1")
    }

    func testDecimalIsWrittenAsLittleEndianBytes() throws {
        let decimal = try XCTUnwrap(MongoDecimal128(string: "1"))
        let document = MongoRawBSON.document([("p", .decimal(decimal))], isArray: false)
        XCTAssertEqual(Array(document.makeData()), Self.oneDecimalDocument)
    }

    func testDatetimeIsWrittenExactly() {
        let document = MongoRawBSON.document([("d", .datetime(1_700_000_000_123))], isArray: false)
        let field = MongoRawBSON.fields(of: document).first
        XCTAssertEqual(field?.type, 0x09)
        XCTAssertEqual(field.map { Array($0.value) }, withUnsafeBytes(of: Int64(1_700_000_000_123).littleEndian, Array.init))
    }

    func testPlainValuesMatchTheLibraryEncoding() {
        var nested = Document()
        nested["x"] = Int32(1)
        var expected = Document()
        expected["name"] = "shop"
        expected["count"] = Int32(5)
        expected["price"] = 2.5
        expected["meta"] = nested
        expected["pattern"] = RegularExpression(pattern: "^a", options: "i")
        let built = MongoRawBSON.document([
            ("name", .value("shop")),
            ("count", .value(Int32(5))),
            ("price", .value(2.5)),
            ("meta", .value(nested)),
            ("pattern", .value(RegularExpression(pattern: "^a", options: "i"))),
        ], isArray: false)
        XCTAssertEqual(built.makeData(), expected.makeData())
    }

    func testFieldsWalkPastEveryValueType() {
        var document = Document()
        document["pattern"] = RegularExpression(pattern: "^a", options: "i")
        document["blob"] = Binary(subType: .uuid, buffer: ByteBuffer(bytes: [1, 2, 3]))
        document["hook"] = JavaScriptCode("return 1")
        document["min"] = MinKey()
        document["last"] = "end"
        XCTAssertEqual(MongoRawBSON.fields(of: document).map(\.key), ["pattern", "blob", "hook", "min", "last"])
    }
}

extension MongoRawBSON.Element {
    var asPrimitive: Primitive? {
        if case let .value(value) = self { return value }
        return nil
    }

    var asDecimal: MongoDecimal128? {
        if case let .decimal(value) = self { return value }
        return nil
    }
}
