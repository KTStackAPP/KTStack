import Foundation
import XCTest
@testable import KTBackupPlugin

final class BackupTriggerPolicyTests: XCTestCase {
    private let policy = BackupTriggerPolicy(calculator: BackupScheduleCalculator(calendar: utcCalendar()))

    private func state(skipOnBattery: Bool = false, runs: [BackupRun] = []) -> (BackupState, UUID) {
        var plan = BackupPlan(name: "Nightly", schedule: BackupSchedule(frequency: .daily, hour: 2, minute: 0),
                              databases: [.init(engine: "mysql", database: "shop")], skipOnBattery: skipOnBattery)
        plan.setEnabled(true, at: date("2026-05-01 00:00:00"))
        return (BackupState(plans: [plan], runs: runs.map { var run = $0; run.planID = plan.id; return run }), plan.id)
    }

    func testLaunchWithSeveralMissedSlotsRunsOneCatchUp() {
        let (initial, id) = state(runs: [BackupRun(planID: UUID(), trigger: .scheduled, startedAt: date("2026-05-03 02:00:00"))])
        let now = date("2026-05-10 09:00:00")
        XCTAssertEqual(policy.actions(state: initial, now: now, onBattery: false, activePlans: []), [.run(id, .catchUp)])
        var after = initial
        after.runs.append(BackupRun(planID: id, trigger: .catchUp, startedAt: now, status: .succeeded))
        XCTAssertEqual(policy.actions(state: after, now: now.addingTimeInterval(60), onBattery: false, activePlans: []), [])
    }

    func testOnTimeEvaluationIsScheduledTrigger() {
        let (initial, id) = state()
        XCTAssertEqual(policy.actions(state: initial, now: date("2026-05-10 02:00:30"), onBattery: false, activePlans: []),
                       [.run(id, .scheduled)])
    }

    func testWakeAfterSlotRunsOnce() {
        let (initial, id) = state(runs: [BackupRun(planID: UUID(), trigger: .scheduled, startedAt: date("2026-05-09 02:00:00"))])
        let wake = date("2026-05-10 07:00:00")
        XCTAssertEqual(policy.actions(state: initial, now: wake, onBattery: false, activePlans: []), [.run(id, .catchUp)])
        XCTAssertEqual(policy.actions(state: initial, now: wake, onBattery: false, activePlans: [id]), [])
    }

    func testBatterySkipIsRecordedOnceThenRetriedOnACPower() {
        let (initial, id) = state(skipOnBattery: true)
        let now = date("2026-05-10 02:00:10")
        XCTAssertEqual(policy.actions(state: initial, now: now, onBattery: true, activePlans: []), [.recordBatterySkip(id)])
        var skipped = initial
        skipped.runs.append(BackupRun(planID: id, trigger: .scheduled, startedAt: now, status: .skipped, skipReason: .onBattery))
        XCTAssertEqual(policy.actions(state: skipped, now: now.addingTimeInterval(600), onBattery: true, activePlans: []), [])
        XCTAssertEqual(policy.actions(state: skipped, now: now.addingTimeInterval(3600), onBattery: false, activePlans: []),
                       [.run(id, .catchUp)])
    }

    func testNextCheckIsEarliestEnabledPlan() {
        let (initial, _) = state()
        XCTAssertEqual(policy.nextCheck(state: initial, now: date("2026-05-10 03:00:00")), date("2026-05-11 02:00:00"))
        XCTAssertNil(policy.nextCheck(state: BackupState(plans: [BackupPlan(name: "off")]), now: Date()))
    }
}
