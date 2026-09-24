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

    func testPlainDocumentIsSavable() {
        var doc = Document()
        doc["_id"] = 1
        doc["tags"] = ["a", "b"] as Document
        XCTAssertNil(MongoLossyFieldScanner.saveRefusal(MongoLossyFieldScanner.scan(doc)))
    }

    func testRecordCarriesRefusalNamingTheField() throws {
        var doc = Document()
        doc["_id"] = 7
        doc["hook"] = JavaScriptCode("return 1")
        let record = try MongoDriver.record(from: doc)
        XCTAssertTrue(record.saveRefusal?.contains("“hook”") == true, record.saveRefusal ?? "")
    }

    func testUpdateRefusesLossyDocumentBeforeWriting() async throws {
        var doc = Document()
        doc["_id"] = 7
        doc["token"] = Binary(subType: .uuid, buffer: ByteBuffer(bytes: [1]))
        let record = try MongoDriver.record(from: doc)
        let driver = MongoDriver(profile: .managedMongo, password: nil, tools: FakeDatabaseTools.allInstalled)
        do {
            try await driver.update(database: "db", collection: "c", record: record, json: record.json)
            XCTFail("a document with a non-generic binary must not be saved")
        } catch {
            guard case let .syntax(message) = error as? DatabaseError else { return XCTFail("\(error)") }
            XCTAssertTrue(message.contains("“token”"), message)
        }
    }
}
