import XCTest
@testable import KTMailPlugin

final class MailModelsDecodingTests: XCTestCase {
    func testDecodeMessageList() throws {
        let json = """
        {"total":1,"unread":1,"count":1,"messages":[
          {"ID":"abc","MessageID":"x@mailpit","Read":false,
           "From":{"Name":"","Address":"app@demo.test"},
           "To":[{"Name":"","Address":"dev@ktstack.test"}],
           "Subject":"Hi","Created":"2026-06-11T21:24:34.473+07:00","Size":797,
           "Attachments":0,"Snippet":"hello"}]}
        """.data(using: .utf8)!
        let resp = try JSONDecoder().decode(MailListResponse.self, from: json)
        XCTAssertEqual(resp.unread, 1)
        let m = try XCTUnwrap(resp.messages.first)
        XCTAssertEqual(m.From?.Address, "app@demo.test")
        XCTAssertEqual(m.Subject, "Hi")
        XCTAssertNotNil(m.date, "RFC3339 fractional-seconds timestamp parses")
    }

    func testDecodeMessageDetail() throws {
        let json = """
        {"ID":"abc","From":{"Name":"App","Address":"app@demo.test"},
         "To":[{"Name":"","Address":"dev@ktstack.test"}],"Cc":null,
         "Subject":"Hi","Date":"2026-06-11T21:24:34.473+07:00",
         "Text":"plain","HTML":"<h1>hi</h1>","Attachments":[]}
        """.data(using: .utf8)!
        let d = try JSONDecoder().decode(MailDetail.self, from: json)
        XCTAssertEqual(d.From?.display, "App <app@demo.test>")
        XCTAssertEqual(d.HTML, "<h1>hi</h1>")
        XCTAssertEqual(d.Text, "plain")
    }
}
