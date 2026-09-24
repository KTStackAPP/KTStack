import MongoKitten
import NIOCore
import XCTest
@testable import KTDatabasePlugin

final class MongoLossyFieldScannerTests: XCTestCase {
    private func document() -> Document {
        var nested = Document()
        nested["pattern"] = RegularExpression(pattern: "^a", options: "i")
        var doc = Document()
        doc["_id"] = 1
        doc["name"] = "plain"
        doc["token"] = Binary(subType: .uuid, buffer: ByteBuffer(bytes: [1, 2, 3, 4]))
        doc["blob"] = Binary(subType: .generic, buffer: ByteBuffer(bytes: [9]))
        doc["meta"] = nested
        doc["hook"] = JavaScriptCode("return 1")
        return doc
    }

    func testFindsLossyTypesWithDottedPaths() {
        let fields = MongoLossyFieldScanner.scan(document())
        XCTAssertEqual(Set(fields.map(\.path)), ["token", "meta.pattern", "hook"])
    }

    func testPlainDocumentHasNoLossyFields() {
        var doc = Document()
        doc["_id"] = 1
        doc["tags"] = ["a", "b"] as Document
        XCTAssertTrue(MongoLossyFieldScanner.scan(doc).isEmpty)
    }
}
