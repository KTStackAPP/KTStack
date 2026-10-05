import Foundation
import XCTest
@testable import KTBackupPlugin

final class BackupScheduleCalculatorTests: XCTestCase {
    private let daily = BackupSchedule(frequency: .daily, hour: 2, minute: 0)

    private func enabledPlan(_ schedule: BackupSchedule, enabledAt: Date = Date(timeIntervalSince1970: 0)) -> BackupPlan {
        var plan = BackupPlan(name: "P", schedule: schedule)
        plan.setEnabled(true, at: enabledAt)
        return plan
    }

    func testDailyNextRunBeforeAndAfterTimeOfDay() {
        let calculator = BackupScheduleCalculator(calendar: utcCalendar())
        let plan = enabledPlan(daily)
        XCTAssertEqual(calculator.nextRun(after: date("2026-05-10 01:59:00"), plan: plan), date("2026-05-10 02:00:00"))
        XCTAssertEqual(calculator.nextRun(after: date("2026-05-10 02:00:00"), plan: plan), date("2026-05-11 02:00:00"))
        XCTAssertEqual(calculator.nextRun(after: date("2026-05-10 13:00:00"), plan: plan), date("2026-05-11 02:00:00"))
    }

    func testWeeklyNextRun() {
        let calculator = BackupScheduleCalculator(calendar: utcCalendar())
        let plan = enabledPlan(BackupSchedule(frequency: .weekly, weekday: 2, hour: 9, minute: 15))
        XCTAssertEqual(calculator.nextRun(after: date("2026-05-10 12:00:00"), plan: plan), date("2026-05-11 09:15:00"))
        XCTAssertEqual(calculator.nextRun(after: date("2026-05-11 08:00:00"), plan: plan), date("2026-05-11 09:15:00"))
        XCTAssertEqual(calculator.nextRun(after: date("2026-05-11 09:15:00"), plan: plan), date("2026-05-18 09:15:00"))
    }

    func testSpringForwardNonexistentTimeRunsAtNextValidTime() {
        let zone = "America/New_York"
        let calculator = BackupScheduleCalculator(calendar: utcCalendar(zone))
        let plan = enabledPlan(BackupSchedule(frequency: .daily, hour: 2, minute: 30))
        let next = calculator.nextRun(after: date("2026-03-07 12:00:00", zone: zone), plan: plan)
        XCTAssertEqual(next, date("2026-03-08 03:00:00", zone: zone))
        XCTAssertEqual(calculator.nextRun(after: next!, plan: plan), date("2026-03-09 02:30:00", zone: zone))
    }

    func testFallBackRepeatedTimeRunsOnce() {
        let zone = "America/New_York"
        let calculator = BackupScheduleCalculator(calendar: utcCalendar(zone))
        let plan = enabledPlan(BackupSchedule(frequency: .daily, hour: 1, minute: 30))
        let first = calculator.nextRun(after: date("2026-10-31 12:00:00", zone: zone), plan: plan)
        XCTAssertEqual(first, date("2026-11-01 05:30:00"))
        XCTAssertEqual(calculator.nextRun(after: first!, plan: plan), date("2026-11-02 06:30:00"))
    }

    func testTimeZoneChangeBetweenRuns() {
        let lastAttempt = date("2026-05-10 02:00:00", zone: "Asia/Ho_Chi_Minh")
        let london = BackupScheduleCalculator(calendar: utcCalendar("Europe/London"))
        let plan = enabledPlan(daily)
        let now = date("2026-05-10 01:30:00", zone: "Europe/London")
        XCTAssertFalse(london.isOverdue(lastAttempt: lastAttempt, now: now, plan: plan))
        XCTAssertEqual(london.nextRun(after: now, plan: plan), date("2026-05-10 02:00:00", zone: "Europe/London"))
        XCTAssertTrue(london.isOverdue(lastAttempt: lastAttempt, now: date("2026-05-10 02:05:00", zone: "Europe/London"), plan: plan))
    }

    func testOverdueOnlyAfterMissedSlot() {
        let calculator = BackupScheduleCalculator(calendar: utcCalendar())
        let plan = enabledPlan(daily)
        XCTAssertTrue(calculator.isOverdue(lastAttempt: date("2026-05-08 02:00:00"), now: date("2026-05-10 09:00:00"), plan: plan))
        XCTAssertFalse(calculator.isOverdue(lastAttempt: date("2026-05-10 02:00:05"), now: date("2026-05-10 09:00:00"), plan: plan))
    }

    func testPlanEnabledAfterLastSlotIsNotOverdue() {
        let calculator = BackupScheduleCalculator(calendar: utcCalendar())
        let plan = enabledPlan(daily, enabledAt: date("2026-05-10 08:00:00"))
        XCTAssertFalse(calculator.isOverdue(lastAttempt: nil, now: date("2026-05-10 09:00:00"), plan: plan))
        XCTAssertTrue(calculator.isOverdue(lastAttempt: nil, now: date("2026-05-11 02:01:00"), plan: plan))
    }

    func testDisabledPlanNeverSchedules() {
        let calculator = BackupScheduleCalculator(calendar: utcCalendar())
        let plan = BackupPlan(name: "Off", schedule: daily)
        XCTAssertNil(calculator.nextRun(after: date("2026-05-10 00:00:00"), plan: plan))
        XCTAssertFalse(calculator.isOverdue(lastAttempt: nil, now: date("2026-05-20 00:00:00"), plan: plan))
    }
}
