import KTStackCore
import XCTest
@testable import KTStackKit

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

final class NginxValueEscapingTests: XCTestCase {
    func testValuesThatBreakNginxQuotingAreRejected() {
        for value in ["a\"b", "$HOME", "a\\b"] {
            XCTAssertEqual(SiteEnvVars.validate(["K": value]), .invalidValue("K"), value)
        }
    }

    func testLegacyInvalidValuesAreLeftOutOfRenderedConfig() {
        let env = ["GOOD": "ok", "BAD": "x\"; include /etc/passwd; #"]
        XCTAssertEqual(SiteEnvVars.renderable(env).map(\.key), ["GOOD"])
        XCTAssertEqual(SiteEnvVars.skippedKeys(env), ["BAD"])
        let config = NginxBackendConfigWriter().config(
            domain: "app.test", root: URL(fileURLWithPath: "/site"), phpFpmSocket: URL(fileURLWithPath: "/run/php.sock"),
            backendPort: 18000, secure: false, pid: URL(fileURLWithPath: "/run/b.pid"),
            accessLog: URL(fileURLWithPath: "/log/a"), errorLog: URL(fileURLWithPath: "/log/e"), env: env
        )
        XCTAssertTrue(config.contains("GOOD"))
        XCTAssertFalse(config.contains("/etc/passwd"))
    }

    func testPathsWithQuotesDollarsOrBackslashesAreUnsafe() {
        XCTAssertTrue(NginxConfigWriter.isSafePath("/Users/me/Sites/app"))
        for path in ["/Users/me/\"x", "/Users/me/$x", "/Users/me/a\\b"] {
            XCTAssertFalse(NginxConfigWriter.isSafePath(path), path)
        }
    }
}
