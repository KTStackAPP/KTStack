import Foundation

public struct BackupScheduleCalculator: Sendable {
    public let calendar: Calendar

    public init(calendar: Calendar) {
        self.calendar = calendar
    }

    public func nextRun(after date: Date, plan: BackupPlan) -> Date? {
        guard plan.isEnabled else { return nil }
        return nextSlot(after: date, schedule: plan.schedule)
    }

    public func nextSlot(after date: Date, schedule: BackupSchedule) -> Date? {
        calendar.nextDate(
            after: date,
            matching: schedule.matchingComponents,
            matchingPolicy: .nextTime,
            repeatedTimePolicy: .first,
            direction: .forward
        )
    }

    public func latestSlot(atOrBefore date: Date, schedule: BackupSchedule) -> Date? {
        guard let start = calendar.date(byAdding: .day, value: -8, to: date) else { return nil }
        var cursor = start
        var latest: Date?
        while let slot = nextSlot(after: cursor, schedule: schedule), slot <= date {
            latest = slot
            cursor = slot
        }
        return latest
    }

    public func isOverdue(lastAttempt: Date?, now: Date, plan: BackupPlan) -> Bool {
        guard plan.isEnabled, let slot = latestSlot(atOrBefore: now, schedule: plan.schedule) else { return false }
        let reference = max(lastAttempt ?? .distantPast, plan.enabledAt ?? .distantPast)
        return slot > reference
    }
}
