import MongoKitten
import NIOCore
import XCTest
@testable import KTDatabasePlugin

final class MongoDocumentDiffTests: XCTestCase {
    private func original() -> Document {
        var address = Document()
        address["city"] = "Hanoi"
        address["zip"] = Int32(10000)
        return MongoRawBSON.document([
            ("_id", .value(1)),
            ("name", .value("shop")),
            ("count", .value(Int32(5))),
            ("price", .value(2.0)),
            ("total", .decimal(MongoDecimal128(string: "19.90")!)),
            ("address", .value(address)),
            ("token", .value(Binary(subType: .uuid, buffer: ByteBuffer(bytes: [1, 2, 3])))),
            ("hook", .value(JavaScriptCode("return 1"))),
        ], isArray: false)
    }

    private func editedJSON(from document: Document? = nil, _ mutate: (inout [String: Any]) -> Void) throws -> String {
        let json = try MongoJSONMapper.encodedJSON(from: document ?? original(), pretty: false)
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(json.utf8)) as? [String: Any])
        mutate(&object)
        return String(decoding: try JSONSerialization.data(withJSONObject: object), as: UTF8.self)
    }

    func testUnchangedDocumentProducesNoUpdate() throws {
        let plan = try MongoDocumentDiff.plan(original: original(), editedJSON: editedJSON { _ in })
        XCTAssertNil(plan.updateDocument)
    }

    func testOnlyChangedPathsAreSet() throws {
        let plan = try MongoDocumentDiff.plan(original: original(), editedJSON: editedJSON { $0["name"] = "store" })
        XCTAssertEqual(plan.set.map { $0.path }, ["name"])
        XCTAssertEqual(plan.element(at: "name")?.asPrimitive as? String, "store")
        XCTAssertTrue(plan.unset.isEmpty)
    }

    func testNestedChangeUsesDottedPathAndKeepsInt32() throws {
        let plan = try MongoDocumentDiff.plan(original: original(), editedJSON: editedJSON {
            var address = $0["address"] as? [String: Any] ?? [:]
            address["zip"] = 10001
            $0["address"] = address
        })
        XCTAssertEqual(plan.set.map { $0.path }, ["address.zip"])
        XCTAssertEqual(plan.element(at: "address.zip")?.asPrimitive as? Int32, 10001)
    }

    func testChangedNumbersKeepTheirOriginalType() throws {
        let plan = try MongoDocumentDiff.plan(original: original(), editedJSON: editedJSON {
            $0["count"] = 6
            $0["price"] = 3
            $0["total"] = 25.5
        })
        XCTAssertEqual(plan.element(at: "count")?.asPrimitive as? Int32, 6)
        XCTAssertEqual(plan.element(at: "price")?.asPrimitive as? Double, 3.0)
        XCTAssertEqual(plan.element(at: "total")?.asDecimal?.description, "25.5")
    }

    func testDecimalEditIsWrittenAsDecimal128() throws {
        let plan = try MongoDocumentDiff.plan(original: original(), editedJSON: editedJSON {
            $0["total"] = ["$numberDecimal": "20.00"]
        })
        let set = try XCTUnwrap(plan.updateDocument?["$set"] as? Document)
        XCTAssertEqual(MongoRawBSON.decimals(in: set)["total"]?.description, "20.00")
    }

    func testFieldsThatUsedToBeRefusedCanNowBeEdited() throws {
        let plan = try MongoDocumentDiff.plan(original: original(), editedJSON: editedJSON {
            $0["hook"] = ["$code": "return 2"]
            $0["token"] = nil
        })
        XCTAssertEqual((plan.element(at: "hook")?.asPrimitive as? JavaScriptCode)?.code, "return 2")
        XCTAssertEqual(plan.unset, ["token"])
    }

    func testRemovedFieldIsUnset() throws {
        let plan = try MongoDocumentDiff.plan(original: original(), editedJSON: editedJSON { $0["name"] = nil })
        XCTAssertEqual(plan.unset, ["name"])
        XCTAssertNotNil(plan.updateDocument?["$unset"])
    }

    func testDocumentWithADeprecatedTypeIsRefusedWithItsName() throws {
        let legacy = MongoLossyFieldScannerTests.documentWithSymbol()
        XCTAssertThrowsError(try MongoDocumentDiff.plan(original: legacy, editedJSON: editedJSON(from: legacy) {
            $0["name"] = "changed"
        })) { error in
            guard case let .syntax(message) = error as? DatabaseError else { return XCTFail("\(error)") }
            XCTAssertTrue(message.contains("“meta.legacy”"), message)
        }
    }

    func testIdIsNeverSetOrUnset() throws {
        let plan = try MongoDocumentDiff.plan(original: original(), editedJSON: editedJSON { $0["_id"] = nil })
        XCTAssertFalse(plan.unset.contains("_id"))
        XCTAssertNil(plan.element(at: "_id"))
    }
}
