import Combine
import Foundation

/// Một tab = một DatabaseV2ViewModel + một connection riêng. Ngắt idle sau `idleInterval` (mặc định 5
/// phút) bằng suspend (giữ rows/staged/scroll); mọi tương tác gọi touch() để dời hạn.
@MainActor
public final class WorkspaceTabSession: Identifiable, ObservableObject {
    public let id = UUID()
    @Published public private(set) var kind: WorkspaceTab
    // Dòng đang chọn của grid tab này; inspector pane cấp cửa sổ đọc theo tab đang active.
    @Published public var selectedRowIndex: Int?
    public let vm: DatabaseV2ViewModel

    private let idleInterval: TimeInterval
    private var idleTask: Task<Void, Never>?
    private var activity: AnyCancellable?
    public private(set) var lastActivity = Date()

    public init(kind: WorkspaceTab, vm: DatabaseV2ViewModel, idleInterval: TimeInterval = 300) {
        self.kind = kind
        self.vm = vm
        self.idleInterval = idleInterval
        activity = vm.objectWillChange.sink { [weak self] _ in
            Task { @MainActor [weak self] in self?.noteActivity() }
        }
    }

    private func noteActivity() {
        guard !vm.isSuspended, Date().timeIntervalSince(lastActivity) > 1 else { return }
        touch()
    }

    func retarget(_ kind: WorkspaceTab) {
        self.kind = kind
    }

    public func touch() {
        lastActivity = Date()
        scheduleIdle()
    }

    private func scheduleIdle() {
        idleTask?.cancel()
        let interval = idleInterval
        idleTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(interval * 1_000_000_000))
            guard !Task.isCancelled else { return }
            await self?.suspend()
        }
    }

    public func suspend() async {
        idleTask?.cancel()
        idleTask = nil
        await vm.suspendConnection()
    }

    public func resume() async {
        await vm.resumeConnection()
        touch()
    }

    public func cancelIdle() {
        idleTask?.cancel()
        idleTask = nil
    }

    deinit {
        idleTask?.cancel()
    }
}
