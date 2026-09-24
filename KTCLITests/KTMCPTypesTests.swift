import XCTest

final class KTMCPTypesTests: XCTestCase {
    func testMessageIdRoundTripsStringAndNumber() throws {
        for id in [KTMCPID.string("abc"), KTMCPID.number(42)] {
            let data = try JSONEncoder().encode(KTMCPMessage(id: id, method: "ping"))
            let decoded = try JSONDecoder().decode(KTMCPMessage.self, from: data)
            XCTAssertEqual(decoded.id, id)
            XCTAssertEqual(decoded.method, "ping")
        }
    }

    func testAnyCodableEncodesNestedPrimitives() throws {
        let value = AnyCodable(["name": AnyCodable("kt"), "count": AnyCodable(2), "ok": AnyCodable(true)])
        let data = try JSONEncoder().encode(value)
        let object = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        XCTAssertEqual(object?["name"] as? String, "kt")
        XCTAssertEqual(object?["count"] as? Int, 2)
        XCTAssertEqual(object?["ok"] as? Bool, true)
    }

    func testParseErrorMessageHasNoId() throws {
        let message = KTMCPMessage(error: KTMCPErrorDetail(code: -32700, message: "Parse error"))
        let data = try JSONEncoder().encode(message)
        let object = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        XCTAssertEqual((object?["error"] as? [String: Any])?["code"] as? Int, -32700)
    }
}
