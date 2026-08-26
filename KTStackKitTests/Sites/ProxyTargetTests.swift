import KTStackCore
import XCTest

final class ProxyTargetTests: XCTestCase {
    private func parsed(_ raw: String) -> ProxyTarget? {
        if case let .success(target) = ProxyTarget.parse(raw) { return target }
        return nil
    }

    private func error(_ raw: String) -> ProxyTargetError? {
        if case let .failure(err) = ProxyTarget.parse(raw) { return err }
        return nil
    }

    func testDefaultsSchemeToHttp() {
        let t = parsed("127.0.0.1:8000")
        XCTAssertEqual(t?.scheme, .http)
        XCTAssertEqual(t?.host, "127.0.0.1")
        XCTAssertEqual(t?.port, 8000)
    }

    func testHttpDefaultsPort80() {
        XCTAssertEqual(parsed("http://example.test")?.port, 80)
    }

    func testHttpsDefaultsPort443() {
        let t = parsed("https://api.example.com")
        XCTAssertEqual(t?.scheme, .https)
        XCTAssertEqual(t?.port, 443)
    }

    func testExplicitHttpsPort() {
        XCTAssertEqual(parsed("https://api.example.com:8443")?.port, 8443)
    }

    func testLocalhostHost() {
        let t = parsed("http://localhost:3000")
        XCTAssertEqual(t?.host, "localhost")
        XCTAssertEqual(t?.port, 3000)
    }

    func testLanIPHost() {
        XCTAssertEqual(parsed("http://192.168.1.20:3000")?.host, "192.168.1.20")
    }

    func testUpstreamURLStringKeepsPort() {
        XCTAssertEqual(parsed("https://api.example.com")?.upstreamURLString, "https://api.example.com:443")
    }

    func testDisplayStringDropsDefaultPort() {
        XCTAssertEqual(parsed("https://api.example.com:443")?.displayString, "https://api.example.com")
        XCTAssertEqual(parsed("http://127.0.0.1:8000")?.displayString, "http://127.0.0.1:8000")
    }

    func testRejectsEmpty() {
        XCTAssertEqual(error("   "), .emptyInput)
    }

    func testRejectsBadScheme() {
        XCTAssertEqual(error("ftp://host:21"), .badScheme)
    }

    func testRejectsPath() {
        XCTAssertEqual(error("http://127.0.0.1:8000/api"), .pathNotAllowed)
    }

    func testRejectsUserinfo() {
        XCTAssertEqual(error("http://user:pass@host:80"), .badHost)
    }

    func testRejectsQuery() {
        XCTAssertEqual(error("http://host:80?x=1"), .badHost)
    }

    func testRejectsInjectionChars() {
        XCTAssertEqual(error("http://host;{}:80"), .badHost)
    }

    func testRejectsPortZero() {
        XCTAssertEqual(error("http://host:0"), .badPort)
    }

    func testRejectsPortTooHigh() {
        XCTAssertEqual(error("http://host:70000"), .badPort)
    }

    func testRejectsEmptyHost() {
        XCTAssertEqual(error("http://:8000"), .badHost)
    }
}
