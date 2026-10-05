import AppKit
import Combine
import Foundation

@MainActor
public final class BackupScheduler: ObservableObject {
    static let tickInterval: TimeInterval = 30

    @Published public private(set) var state: BackupState
    @Published public private(set) var phases: [UUID: BackupRunPhase] = [:]

    let coordinator: BackupCoordinator
    let store: BackupStore
    let policy: BackupTriggerPolicy
    private let notifier = BackupNotifier()
    private var tasks: [UUID: Task<Void, Never>] = [:]
    private var timer: Timer?
    private var wakeObserver: NSObjectProtocol?
    private var powerSource: CFRunLoopSource?

    init(coordinator: BackupCoordinator, store: BackupStore, calendar: Calendar = .autoupdatingCurrent) {
        self.coordinator = coordinator
        self.store = store
        policy = BackupTriggerPolicy(calculator: BackupScheduleCalculator(calendar: calendar))
        state = store.snapshot
    }

    public var calculator: BackupScheduleCalculator {
        policy.calculator
    }

    public var hasActiveRuns: Bool {
        !tasks.isEmpty
    }

    public var activePlanNames: [String] {
        tasks.keys.compactMap { state.plan($0)?.name }.sorted()
    }

    func start() {
        coordinator.markInterruptedRuns()
        reload()
        timer = Timer.scheduledTimer(withTimeInterval: Self.tickInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.evaluate() }
        }
        wakeObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification, object: nil, queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.evaluate() }
        }
        powerSource = PowerSource.observeChanges { [weak self] in
            Task { @MainActor in self?.evaluate() }
        }
        evaluate()
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        if let wakeObserver { NSWorkspace.shared.notificationCenter.removeObserver(wakeObserver) }
        wakeObserver = nil
        if let powerSource { CFRunLoopRemoveSource(CFRunLoopGetMain(), powerSource, .defaultMode) }
        powerSource = nil
    }

    func evaluate() {
        let actions = policy.actions(state: store.snapshot, now: Date(), onBattery: PowerSource.isOnBattery(),
                                     activePlans: Set(tasks.keys))
        for action in actions {
            switch action {
            case let .run(planID, trigger):
                launch(planID, trigger: trigger)
            case let .recordBatterySkip(planID):
                coordinator.recordSkip(planID: planID, reason: .onBattery)
            }
        }
        reload()
    }

    public func runNow(_ planID: UUID) {
        launch(planID, trigger: .manual)
    }

    public func isRunning(_ planID: UUID) -> Bool {
        tasks[planID] != nil
    }

    public func update(_ body: (inout BackupState) -> Void) throws {
        state = try store.update(body)
    }

    public func reload() {
        state = store.snapshot
    }

    public func nextRun(for plan: BackupPlan) -> Date? {
        calculator.nextRun(after: Date(), plan: plan)
    }

    private func launch(_ planID: UUID, trigger: BackupTrigger) {
        guard tasks[planID] == nil, let plan = store.snapshot.plan(planID) else { return }
        phases[planID] = .staging
        let coordinator = coordinator
        tasks[planID] = Task { [weak self] in
            let run = await coordinator.run(planID: planID, trigger: trigger) { id, phase in
                Task { @MainActor in self?.updatePhase(id, phase) }
            }
            self?.finish(planID, planName: plan.name, run: run)
        }
        reload()
    }

    private func updatePhase(_ planID: UUID, _ phase: BackupRunPhase) {
        guard tasks[planID] != nil else { return }
        phases[planID] = phase
    }

    private func finish(_ planID: UUID, planName: String, run: BackupRun?) {
        tasks[planID] = nil
        phases[planID] = nil
        if let run { notifier.notifyFailure(planName: planName, run: run) }
        reload()
    }
}
