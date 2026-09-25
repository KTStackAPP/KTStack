import MongoKitten
import XCTest
@testable import KTDatabasePlugin

final class MongoJSONMapperExtendedJSONTests: XCTestCase {
    private func encoded(_ document: Document) throws -> [String: Any] {
        let json = try MongoJSONMapper.encodedJSON(from: document, pretty: false)
        return try XCTUnwrap(JSONSerialization.jsonObject(with: Data(json.utf8)) as? [String: Any])
    }

    private func roundTrip(_ json: String) throws -> [String: Any] {
        try encoded(MongoJSONMapper.document(fromJSON: json))
    }

    func testDecimal128FromTheServerShowsItsValue() throws {
        let document = Document(bytes: MongoRawBSONTests.oneDecimalDocument)
        let price = try XCTUnwrap(encoded(document)["p"] as? [String: Any])
        XCTAssertEqual(price["$numberDecimal"] as? String, "1")
    }

    func testDecimal128RoundTripsThroughTheEditor() throws {
        let document = try MongoJSONMapper.document(fromJSON: #"{"price":{"$numberDecimal":"19.90"}}"#)
        XCTAssertEqual(MongoRawBSON.decimals(in: document)["price"]?.description, "19.90")
        let price = try XCTUnwrap(encoded(document)["price"] as? [String: Any])
        XCTAssertEqual(price["$numberDecimal"] as? String, "19.90")
    }

    func testCanonicalWrappersRoundTrip() throws {
        let json = #"""
        {"re":{"$regularExpression":{"pattern":"^a","options":"i"}},"code":{"$code":"return 1"},
         "min":{"$minKey":1},"max":{"$maxKey":1},
         "uuid":{"$binary":{"base64":"AQIDBAUGBwgJCgsMDQ4PEA==","subType":"04"}},
         "inf":{"$numberDouble":"-Infinity"},"old":{"$date":{"$numberLong":"-1000"}}}
        """#
        let result = try roundTrip(json)
        XCTAssertEqual((result["re"] as? [String: Any])?["$regularExpression"] as? [String: String], ["pattern": "^a", "options": "i"])
        XCTAssertEqual((result["code"] as? [String: Any])?["$code"] as? String, "return 1")
        XCTAssertEqual((result["min"] as? [String: Any])?["$minKey"] as? Int, 1)
        XCTAssertEqual((result["max"] as? [String: Any])?["$maxKey"] as? Int, 1)
        let uuid = (result["uuid"] as? [String: Any])?["$binary"] as? [String: String]
        XCTAssertEqual(uuid, ["base64": "AQIDBAUGBwgJCgsMDQ4PEA==", "subType": "04"])
        XCTAssertEqual((result["inf"] as? [String: Any])?["$numberDouble"] as? String, "-Infinity")
        XCTAssertEqual(((result["old"] as? [String: Any])?["$date"] as? [String: Any])?["$numberLong"] as? String, "-1000")
    }

    func testExplicitNumberWrappersKeepTheirType() throws {
        let document = try MongoJSONMapper.document(
            fromJSON: #"{"i":{"$numberInt":"5"},"l":{"$numberLong":"9007199254740993"},"d":{"$numberDouble":"2.0"}}"#
        )
        XCTAssertEqual(document["i"] as? Int32, 5)
        XCTAssertEqual(document["l"] as? Int, 9_007_199_254_740_993)
        XCTAssertEqual(document["d"] as? Double, 2.0)
    }

    func testDateMillisecondsAreStoredExactly() throws {
        let document = try MongoJSONMapper.document(fromJSON: #"{"d":{"$date":"2023-11-14T22:13:20.123Z"}}"#)
        let field = try XCTUnwrap(MongoRawBSON.fields(of: document).first)
        XCTAssertEqual(Array(field.value), withUnsafeBytes(of: Int64(1_700_000_000_123).littleEndian, Array.init))
        XCTAssertEqual((try encoded(document)["d"] as? [String: Any])?["$date"] as? String, "2023-11-14T22:13:20.123Z")
    }

    func testQueryOperatorsAreNotTreatedAsWrappers() throws {
        let document = try MongoJSONMapper.document(fromJSON: #"{"age":{"$gt":5},"name":{"$regex":"^a","$options":"i"}}"#)
        XCTAssertEqual((document["age"] as? Document)?["$gt"] as? Int, 5)
        XCTAssertEqual((document["name"] as? Document)?["$regex"] as? String, "^a")
    }

    func testInvalidWrapperIsReported() {
        XCTAssertThrowsError(try MongoJSONMapper.document(fromJSON: #"{"p":{"$numberDecimal":"abc"}}"#)) { error in
            guard case let .syntax(message) = error as? DatabaseError else { return XCTFail("\(error)") }
            XCTAssertTrue(message.contains("$numberDecimal"), message)
        }
    }

    func testIdentifierJSONIsStableForDecimalIds() throws {
        let document = try MongoJSONMapper.document(fromJSON: #"{"_id":{"$numberDecimal":"7"}}"#)
        XCTAssertEqual(MongoJSONMapper.identifierJSON(in: document), #"{"$numberDecimal":"7"}"#)
        XCTAssertEqual(MongoJSONMapper.displayID(in: document), "7")
    }
}
