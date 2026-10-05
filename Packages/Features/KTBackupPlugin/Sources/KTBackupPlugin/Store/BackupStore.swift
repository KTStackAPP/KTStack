import Foundation

public struct BackupState: Equatable, Sendable {
    public var plans: [BackupPlan]
    public var destinations: [BackupDestination]
    public var runs: [BackupRun]

    public init(plans: [BackupPlan] = [], destinations: [BackupDestination] = [], runs: [BackupRun] = []) {
        self.plans = plans
        self.destinations = destinations
        self.runs = runs
    }

    public func plan(_ id: UUID) -> BackupPlan? {
        plans.first { $0.id == id }
    }

    public func destination(_ id: UUID?) -> BackupDestination? {
        guard let id else { return nil }
        return destinations.first { $0.id == id }
    }

    public func runs(for planID: UUID) -> [BackupRun] {
        runs.filter { $0.planID == planID }.sorted { $0.startedAt > $1.startedAt }
    }

    public func lastRun(for planID: UUID) -> BackupRun? {
        runs(for: planID).first
    }
}

public final class BackupStore: @unchecked Sendable {
    public static let runsPerPlanLimit = 50

    private let lock = NSLock()
    private let plansFile: JSONFileStore<[BackupPlan]>
    private let destinationsFile: JSONFileStore<[BackupDestination]>
    private let runsFile: JSONFileStore<[BackupRun]>
    private var state: BackupState

    public init(paths: BackupPaths) {
        plansFile = JSONFileStore(url: paths.plansFile, fallback: [])
        destinationsFile = JSONFileStore(url: paths.destinationsFile, fallback: [])
        runsFile = JSONFileStore(url: paths.runsFile, fallback: [])
        state = BackupState(plans: plansFile.load(), destinations: destinationsFile.load(), runs: runsFile.load())
    }

    public var snapshot: BackupState {
        lock.lock()
        defer { lock.unlock() }
        return state
    }

    @discardableResult
    public func update(_ body: (inout BackupState) -> Void) throws -> BackupState {
        lock.lock()
        defer { lock.unlock() }
        var next = state
        body(&next)
        next.runs = Self.trimmed(next.runs)
        if next.plans != state.plans { try plansFile.save(next.plans) }
        if next.destinations != state.destinations { try destinationsFile.save(next.destinations) }
        if next.runs != state.runs { try runsFile.save(next.runs) }
        state = next
        return next
    }

    public func record(_ run: BackupRun) throws {
        try update { state in
            if let index = state.runs.firstIndex(where: { $0.id == run.id }) {
                state.runs[index] = run
            } else {
                state.runs.append(run)
            }
        }
    }

    static func trimmed(_ runs: [BackupRun]) -> [BackupRun] {
        let grouped = Dictionary(grouping: runs, by: \.planID)
        let kept = grouped.values.flatMap { planRuns in
            planRuns.sorted { $0.startedAt > $1.startedAt }.prefix(runsPerPlanLimit)
        }
        return kept.sorted { $0.startedAt < $1.startedAt }
    }
}
