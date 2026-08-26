import KTPlatformContracts
import XCTest
@testable import KTRuntimesPlugin

final class RuntimeDownloadProgressTextTests: XCTestCase {
    func testStartingWhenTotalUnknown() {
        let progress = RuntimeDownloadProgress(version: "8.3", received: 0, total: 0)
        XCTAssertEqual(progress.progressText, "Starting…")
    }

    func testPercentAndBytes() {
        let progress = RuntimeDownloadProgress(version: "8.3", received: 40_000_000, total: 64_000_000)
        let text = progress.progressText
        XCTAssertTrue(text.hasPrefix("62% · "), text)
        XCTAssertTrue(text.contains("/"), text)
        XCTAssertTrue(text.contains("MB"), text)
    }
}
