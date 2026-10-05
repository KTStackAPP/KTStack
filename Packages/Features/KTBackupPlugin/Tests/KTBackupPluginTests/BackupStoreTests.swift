import Foundation
import XCTest
@testable import KTBackupPlugin

final class BackupStoreTests: XCTestCase {
    func testSaveAndReload() throws {
        let paths = BackupPaths(appSupportRoot: try makeTemporaryDirectory())
        let store = BackupStore(paths: paths)
        let plan = BackupPlan(name: "Nightly")
        let destination = BackupDestination(name: "Disk", kind: .local, local: .init(path: "/tmp"))
        try store.update {
            $0.plans = [plan]
            $0.destinations = [destination]
        }
        try store.record(BackupRun(planID: plan.id, trigger: .manual, startedAt: Date(timeIntervalSince1970: 10)))
        let reloaded = BackupStore(paths: paths).snapshot
        XCTAssertEqual(reloaded.plans, [plan])
        XCTAssertEqual(reloaded.destinations, [destination])
        XCTAssertEqual(reloaded.runs.count, 1)
    }

    func testRecordReplacesRunWithSameID() throws {
        let store = BackupStore(paths: BackupPaths(appSupportRoot: try makeTemporaryDirectory()))
        var run = BackupRun(planID: UUID(), trigger: .manual, startedAt: Date())
        try store.record(run)
        run.status = .succeeded
        try store.record(run)
        XCTAssertEqual(store.snapshot.runs, [run])
    }

    func testAtomicReplaceLeavesNoTemporaryFiles() throws {
        let paths = BackupPaths(appSupportRoot: try makeTemporaryDirectory())
        let store = BackupStore(paths: paths)
        for index in 0..<5 {
            try store.update { $0.plans = [BackupPlan(name: "Plan \(index)")] }
        }
        let files = try FileManager.default.contentsOfDirectory(atPath: paths.root.path)
        XCTAssertEqual(files.sorted(), ["plans.json"])
        XCTAssertEqual(BackupStore(paths: paths).snapshot.plans.first?.name, "Plan 4")
    }

    func testCorruptedFileFallsBackAndIsQuarantined() throws {
        let paths = BackupPaths(appSupportRoot: try makeTemporaryDirectory())
        try FileManager.default.createDirectory(at: paths.root, withIntermediateDirectories: true)
        try Data("{not json".utf8).write(to: paths.plansFile)
        let store = BackupStore(paths: paths)
        XCTAssertTrue(store.snapshot.plans.isEmpty)
        let files = try FileManager.default.contentsOfDirectory(atPath: paths.root.path)
        XCTAssertTrue(files.contains { $0.hasPrefix("plans.json.corrupt-") })
        XCTAssertFalse(files.contains("plans.json"))
    }

    func testRunsAreCappedPerPlan() throws {
        let store = BackupStore(paths: BackupPaths(appSupportRoot: try makeTemporaryDirectory()))
        let busy = UUID()
        let quiet = UUID()
        try store.update { state in
            state.runs = (0..<(BackupStore.runsPerPlanLimit + 10)).map {
                BackupRun(planID: busy, trigger: .scheduled, startedAt: Date(timeIntervalSince1970: TimeInterval($0)))
            }
            state.runs.append(BackupRun(planID: quiet, trigger: .manual, startedAt: Date(timeIntervalSince1970: 0)))
        }
        let snapshot = store.snapshot
        XCTAssertEqual(snapshot.runs(for: busy).count, BackupStore.runsPerPlanLimit)
        XCTAssertEqual(snapshot.runs(for: busy).last?.startedAt, Date(timeIntervalSince1970: 10))
        XCTAssertEqual(snapshot.runs(for: quiet).count, 1)
    }
}
