import KTStackCore
import XCTest

final class SiteEnvVarsTests: XCTestCase {
    func testValidEnvPasses() {
        XCTAssertNil(SiteEnvVars.validate(["APP_DEBUG": "1", "_x9": "value with spaces"]))
    }

    func testInvalidKeyRejected() {
        XCTAssertEqual(SiteEnvVars.validate(["1abc": "x"]), .invalidKey("1abc"))
        XCTAssertEqual(SiteEnvVars.validate(["a-b": "x"]), .invalidKey("a-b"))
        XCTAssertEqual(SiteEnvVars.validate(["": "x"]), .invalidKey(""))
    }

    func testReservedKeyRejected() {
        XCTAssertEqual(SiteEnvVars.validate(["SERVER_NAME": "x"]), .reservedKey("SERVER_NAME"))
        XCTAssertEqual(SiteEnvVars.validate(["PORT": "3000"]), .reservedKey("PORT"))
        XCTAssertEqual(SiteEnvVars.validate(["HTTPS": "on"]), .reservedKey("HTTPS"))
    }

    func testNewlineValueRejected() {
        XCTAssertEqual(SiteEnvVars.validate(["K": "a\nb"]), .invalidValue("K"))
        XCTAssertEqual(SiteEnvVars.validate(["K": "a\rb"]), .invalidValue("K"))
        XCTAssertEqual(SiteEnvVars.validate(["K": "a\u{0}b"]), .invalidValue("K"))
    }

    func testSortedIsStable() {
        let sorted = SiteEnvVars.sorted(["B": "2", "A": "1", "C": "3"])
        XCTAssertEqual(sorted.map(\.key), ["A", "B", "C"])
        XCTAssertEqual(sorted.map(\.value), ["1", "2", "3"])
    }
}
