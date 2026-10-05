import Foundation

public enum BackupRunPhase: Equatable, Sendable {
    case staging
    case uploading(Double)
    case cleaningUp
}

public protocol BackupDestinationClientMaking: Sendable {
    func client(for destination: BackupDestination?) throws -> any BackupDestinationClient
    func localArchivesClient() -> any BackupDestinationClient
}

public final class BackupCoordinator: Sendable {
    public typealias PhaseHandler = @Sendable (UUID, BackupRunPhase) -> Void

    let store: BackupStore
    let runner: BackupPlanRunner
    let destinations: any BackupDestinationClientMaking
    let logger: BackupLogger
    let now: @Sendable () -> Date

    public init(store: BackupStore, runner: BackupPlanRunner, destinations: any BackupDestinationClientMaking,
                logger: BackupLogger, now: @escaping @Sendable () -> Date = { Date() }) {
        self.store = store
        self.runner = runner
        self.destinations = destinations
        self.logger = logger
        self.now = now
    }

    public func isRunning(_ planID: UUID) async -> Bool {
        await runner.isRunning(planID)
    }

    @discardableResult
    public func run(planID: UUID, trigger: BackupTrigger, onPhase: @escaping PhaseHandler = { _, _ in }) async -> BackupRun? {
        guard let plan = store.snapshot.plan(planID) else { return nil }
        var run = BackupRun(planID: plan.id, trigger: trigger, startedAt: now())
        try? store.record(run)
        onPhase(plan.id, .staging)
        do {
            switch try await runner.stage(plan, at: run.startedAt) {
            case let .skipped(reason):
                run.status = .skipped
                run.skipReason = reason
                run.message = reason.message
            case let .staged(staged):
                try await deliver(staged, plan: plan, run: &run, onPhase: onPhase)
            }
        } catch BackupPipelineError.alreadyRunning {
            return nil
        } catch {
            run.status = .failed
            run.message = error.localizedDescription
        }
        run.finishedAt = now()
        try? store.record(run)
        logger.log(Self.logLine(plan: plan, run: run))
        return run
    }

    public func recordSkip(planID: UUID, reason: BackupSkipReason) {
        let date = now()
        let run = BackupRun(planID: planID, trigger: .scheduled, startedAt: date, finishedAt: date, status: .skipped,
                            skipReason: reason, message: reason.message)
        try? store.record(run)
        logger.log("Plan \(planID.uuidString) skipped: \(reason.message)")
    }

    public func markInterruptedRuns() {
        _ = try? store.update { state in
            for index in state.runs.indices where state.runs[index].status == .running {
                state.runs[index].status = .failed
                state.runs[index].finishedAt = state.runs[index].startedAt
                state.runs[index].message = "Interrupted because KTStack quit during the backup."
            }
        }
    }

    static func logLine(plan: BackupPlan, run: BackupRun) -> String {
        var line = "Plan \"\(plan.name)\" (\(run.trigger.rawValue)): \(run.status.rawValue)"
        if let message = run.message { line += " - \(message)" }
        let failures = run.items.filter { !$0.succeeded }.map { "\($0.name): \($0.message ?? "failed")" }
        if !failures.isEmpty { line += " [\(failures.joined(separator: "; "))]" }
        if !run.warnings.isEmpty { line += " warnings: \(run.warnings.joined(separator: "; "))" }
        return line
    }
}
