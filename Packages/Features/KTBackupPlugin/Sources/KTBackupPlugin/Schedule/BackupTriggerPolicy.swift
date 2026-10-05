import Foundation

public enum BackupTriggerAction: Equatable, Sendable {
    case run(UUID, BackupTrigger)
    case recordBatterySkip(UUID)
}

public struct BackupTriggerPolicy: Sendable {
    public static let onTimeWindow: TimeInterval = 10 * 60

    public let calculator: BackupScheduleCalculator

    public init(calculator: BackupScheduleCalculator) {
        self.calculator = calculator
    }

    public func actions(state: BackupState, now: Date, onBattery: Bool, activePlans: Set<UUID>) -> [BackupTriggerAction] {
        state.plans.compactMap { plan in
            guard plan.isEnabled, !activePlans.contains(plan.id) else { return nil }
            return action(for: plan, runs: state.runs(for: plan.id), now: now, onBattery: onBattery)
        }
    }

    public func nextCheck(state: BackupState, now: Date) -> Date? {
        state.plans.compactMap { calculator.nextRun(after: now, plan: $0) }.min()
    }

    private func action(for plan: BackupPlan, runs: [BackupRun], now: Date, onBattery: Bool) -> BackupTriggerAction? {
        let lastAttempt = runs.filter(\.countsAsAttempt).map(\.startedAt).max()
        guard calculator.isOverdue(lastAttempt: lastAttempt, now: now, plan: plan),
              let slot = calculator.latestSlot(atOrBefore: now, schedule: plan.schedule) else { return nil }
        if plan.skipOnBattery && onBattery {
            let alreadyRecorded = runs.contains { $0.skipReason == .onBattery && $0.startedAt >= slot }
            return alreadyRecorded ? nil : .recordBatterySkip(plan.id)
        }
        let trigger: BackupTrigger = now.timeIntervalSince(slot) <= Self.onTimeWindow ? .scheduled : .catchUp
        return .run(plan.id, trigger)
    }
}
