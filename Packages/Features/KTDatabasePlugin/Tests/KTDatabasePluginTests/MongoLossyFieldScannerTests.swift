import MongoKitten
import NIOCore
import XCTest
@testable import KTDatabasePlugin

final class MongoLossyFieldScannerTests: XCTestCase {
    static func documentWithSymbol() -> Document {
        let symbol: [UInt8] = [0x0E] + Array("legacy".utf8) + [0, 3, 0, 0, 0, 0x61, 0x62, 0]
        let nested = Document(bytes: [UInt8(symbol.count + 5), 0, 0, 0] + symbol + [0])
        var document = Document()
        document["_id"] = 1
        document["name"] = "plain"
        document["meta"] = nested
        return document
    }

    func testFindsDeprecatedTypesWithDottedPaths() {
        XCTAssertEqual(
            MongoLossyFieldScanner.scan(Self.documentWithSymbol()),
            [MongoLossyField(path: "meta.legacy", typeName: "symbol")]
        )
    }

    func testTypesExtendedJSONCanCarryAreNotFlagged() {
        var doc = Document()
        doc["_id"] = 1
        doc["tags"] = ["a", "b"] as Document
        doc["token"] = Binary(subType: .uuid, buffer: ByteBuffer(bytes: [1, 2, 3, 4]))
        doc["pattern"] = RegularExpression(pattern: "^a", options: "i")
        doc["hook"] = JavaScriptCode("return 1")
        XCTAssertTrue(MongoLossyFieldScanner.scan(doc).isEmpty)
    }
}
