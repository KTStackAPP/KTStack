import Foundation
import XCTest
@testable import KTBackupPlugin

final class BackupFormattingTests: XCTestCase {
    func testRecentAndSlightlyFutureDatesReadAsJustNow() {
        let now = Date()
        XCTAssertEqual(BackupFormatting.relative(now, now: now), "just now")
        XCTAssertEqual(BackupFormatting.relative(now.addingTimeInterval(0.2), now: now), "just now")
        XCTAssertEqual(BackupFormatting.relative(now.addingTimeInterval(-59), now: now), "just now")
    }

    func testOlderDatesUseRelativeFormatting() {
        let now = Date()
        let text = BackupFormatting.relative(now.addingTimeInterval(-300), now: now)
        XCTAssertNotEqual(text, "just now")
        XCTAssertFalse(text.hasPrefix("in "))
    }
}
