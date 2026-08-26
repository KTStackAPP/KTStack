import KTPlatformContracts
import KTStackCore
import XCTest
@testable import KTStackKit

final class RouteIntrospectionServiceTests: XCTestCase {
    private let fm = FileManager.default

    func testResolvedIniIsNilWhenFileMissing() {
        let missing = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("kd-ini-\(UUID().uuidString).ini")
        XCTAssertNil(RouteIntrospectionService.resolvedIni(missing))
    }

    func testResolvedIniIsURLWhenFileExists() throws {
        let url = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("kd-ini-\(UUID().uuidString).ini")
        try "memory_limit=256M".write(to: url, atomically: true, encoding: .utf8)
        defer { try? fm.removeItem(at: url) }
        XCTAssertEqual(RouteIntrospectionService.resolvedIni(url), url)
    }
}
