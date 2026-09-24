import XCTest
@testable import KTStackKit

final class ResourceLeakTests: XCTestCase {
    func testHTTPProbesShareOneSession() async {
        let first = HealthChecker.probeSession
        let reachable = await HealthChecker.httpReachable(URL(string: "http://127.0.0.1:9/")!, timeout: 0.5)
        XCTAssertFalse(reachable)
        XCTAssertTrue(first === HealthChecker.probeSession)
    }

    func testRepeatedProbesDoNotGrowOpenDescriptors() async {
        let url = URL(string: "http://127.0.0.1:9/")!
        _ = await HealthChecker.httpReachable(url, timeout: 0.5)
        let growth = await FileDescriptorCounter.delta {
            for _ in 0..<30 { _ = await HealthChecker.httpReachable(url, timeout: 0.2) }
        }
        XCTAssertLessThan(growth, 10)
    }

    func testRestoreToolFailureCarriesStderr() throws {
        let bogus = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("kd-not-a-zip-\(UUID().uuidString).zip")
        try Data("plain text".utf8).write(to: bogus)
        defer { try? FileManager.default.removeItem(at: bogus) }
        XCTAssertThrowsError(try RestoreShellTools.zipEntries(bogus)) { error in
            XCTAssertTrue("\(error)".contains("unzip"), "\(error)")
        }
    }
}
