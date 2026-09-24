import MongoKitten
import NIOCore
import XCTest
@testable import KTDatabasePlugin

final class MongoDocumentDiffTests: XCTestCase {
    private func original() -> Document {
        var address = Document()
        address["city"] = "Hanoi"
        address["zip"] = Int32(10000)
        var doc = Document()
        doc["_id"] = 1
        doc["name"] = "shop"
        doc["count"] = Int32(5)
        doc["price"] = 2.0
        doc["address"] = address
        doc["token"] = Binary(subType: .uuid, buffer: ByteBuffer(bytes: [1, 2, 3]))
        doc["hook"] = JavaScriptCode("return 1")
        return doc
    }

    private func editedJSON(_ mutate: (inout [String: Any]) -> Void) throws -> String {
        let json = try MongoJSONMapper.encodedJSON(from: original(), pretty: false)
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(json.utf8)) as? [String: Any])
        mutate(&object)
        return String(decoding: try JSONSerialization.data(withJSONObject: object), as: UTF8.self)
    }

    func testUnchangedDocumentProducesNoUpdate() throws {
        let plan = try MongoDocumentDiff.plan(original: original(), editedJSON: editedJSON { _ in })
        XCTAssertNil(plan.updateDocument)
    }

    func testOnlyChangedPathsAreSetAndLossyFieldsAreLeftAlone() throws {
        let plan = try MongoDocumentDiff.plan(original: original(), editedJSON: editedJSON { $0["name"] = "store" })
        XCTAssertEqual(plan.set.keys, ["name"])
        XCTAssertEqual(plan.set["name"] as? String, "store")
        XCTAssertTrue(plan.unset.isEmpty)
    }

    func testNestedChangeUsesDottedPathAndKeepsInt32() throws {
        let plan = try MongoDocumentDiff.plan(original: original(), editedJSON: editedJSON {
            var address = $0["address"] as? [String: Any] ?? [:]
            address["zip"] = 10001
            $0["address"] = address
        })
        XCTAssertEqual(plan.set.keys, ["address.zip"])
        XCTAssertEqual(plan.set["address.zip"] as? Int32, 10001)
    }

    func testChangedNumbersKeepTheirOriginalType() throws {
        let plan = try MongoDocumentDiff.plan(original: original(), editedJSON: editedJSON {
            $0["count"] = 6
            $0["price"] = 3
        })
        XCTAssertEqual(plan.set["count"] as? Int32, 6)
        XCTAssertEqual(plan.set["price"] as? Double, 3.0)
    }

    func testRemovedFieldIsUnset() throws {
        let plan = try MongoDocumentDiff.plan(original: original(), editedJSON: editedJSON { $0["name"] = nil })
        XCTAssertEqual(plan.unset, ["name"])
        XCTAssertNotNil(plan.updateDocument?["$unset"])
    }

    func testEditingALossyFieldIsRefusedWithItsName() throws {
        XCTAssertThrowsError(try MongoDocumentDiff.plan(original: original(), editedJSON: editedJSON {
            $0["hook"] = "return 2"
        })) { error in
            guard case let .syntax(message) = error as? DatabaseError else { return XCTFail("\(error)") }
            XCTAssertTrue(message.contains("“hook”"), message)
        }
        XCTAssertThrowsError(try MongoDocumentDiff.plan(original: original(), editedJSON: editedJSON { $0["token"] = nil }))
    }

    func testIdIsNeverSetOrUnset() throws {
        let plan = try MongoDocumentDiff.plan(original: original(), editedJSON: editedJSON { $0["_id"] = nil })
        XCTAssertFalse(plan.unset.contains("_id"))
        XCTAssertNil(plan.set["_id"])
    }
}
