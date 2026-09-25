import XCTest
@testable import KTDatabasePlugin

final class MongoDecimal128Tests: XCTestCase {
    private func assertBits(_ text: String, high: UInt64, low: UInt64, canonical: String? = nil, line: UInt = #line) {
        let decimal = MongoDecimal128(string: text)
        XCTAssertEqual(decimal, MongoDecimal128(low: low, high: high), text, line: line)
        XCTAssertEqual(MongoDecimal128(low: low, high: high).description, canonical ?? text, line: line)
    }

    func testSpecificationVectors() {
        assertBits("0", high: 0x3040_0000_0000_0000, low: 0)
        assertBits("-0", high: 0xB040_0000_0000_0000, low: 0)
        assertBits("1", high: 0x3040_0000_0000_0000, low: 1)
        assertBits("-1", high: 0xB040_0000_0000_0000, low: 1)
        assertBits("0.1", high: 0x303E_0000_0000_0000, low: 1)
        assertBits("-0.0", high: 0xB03E_0000_0000_0000, low: 0)
        assertBits("0.001234", high: 0x3034_0000_0000_0000, low: 0x4D2)
        assertBits("0.00123400000", high: 0x302A_0000_0000_0000, low: 0x75A_EF40)
        assertBits("123456789012", high: 0x3040_0000_0000_0000, low: 0x1C_BE99_1A14)
        assertBits("1.234E+3", high: 0x3040_0000_0000_0000, low: 0x4D2, canonical: "1234")
        assertBits("1E+3", high: 0x3046_0000_0000_0000, low: 1)
        assertBits("0.0000001234", high: 0x302C_0000_0000_0000, low: 0x4D2, canonical: "1.234E-7")
        assertBits("1E-6176", high: 0, low: 1)
        assertBits(
            "9.999999999999999999999999999999999E+6144",
            high: 0x5FFF_ED09_BEAD_87C0,
            low: 0x378D_8E63_FFFF_FFFF
        )
    }

    func testSpecialValues() {
        assertBits("Infinity", high: 0x7800_0000_0000_0000, low: 0)
        assertBits("-Infinity", high: 0xF800_0000_0000_0000, low: 0)
        assertBits("NaN", high: 0x7C00_0000_0000_0000, low: 0)
    }

    func testLargeExponentIsClampedWithoutChangingTheValue() {
        assertBits("1E+6112", high: 0x5FFE_0000_0000_0000, low: 10, canonical: "1.0E+6112")
    }

    func testInexactOrMalformedInputIsRejected() {
        XCTAssertNil(MongoDecimal128(string: "12345678901234567890123456789012345"))
        XCTAssertNil(MongoDecimal128(string: "1E-6177"))
        XCTAssertNil(MongoDecimal128(string: "abc"))
        XCTAssertNil(MongoDecimal128(string: "1.2.3"))
        XCTAssertNil(MongoDecimal128(string: ""))
    }

    func testTrailingZerosBeyond34DigitsAreDropped() {
        XCTAssertEqual(
            MongoDecimal128(string: "1234567890123456789012345678901234000"),
            MongoDecimal128(string: "1234567890123456789012345678901234E+3")
        )
    }
}
