import Combine
import Foundation

/// Một cửa sổ/tab workspace = một session độc lập: shell nối kết nối (sidebar/landing/đổi DB) +
/// store gom tab object riêng. Sống theo cửa sổ, giải phóng khi tab đóng.
@MainActor
public final class WorkspaceSession: ObservableObject, Identifiable {
    public let id = UUID()
    public let store: WorkspaceStore
    public let shell: DatabaseV2ViewModel
    @Published public private(set) var title = "KTStack Database"

    private var cancellables: Set<AnyCancellable> = []

    public init(store: WorkspaceStore, shell: DatabaseV2ViewModel) {
        self.store = store
        self.shell = shell
        Publishers.CombineLatest(store.$selectedProfileID, store.$profiles)
            .sink { [weak self] id, profiles in
                self?.title = Self.windowTitle(for: id, in: profiles)
            }
            .store(in: &cancellables)
    }

    public var connectedProfileID: UUID? { store.selectedProfileID }
    public var pendingChangeTotal: Int { store.pendingChangeTotal }

    private static func windowTitle(for id: UUID?, in profiles: [ConnectionProfile]) -> String {
        guard let id, let profile = profiles.first(where: { $0.id == id }) else { return "KTStack Database" }
        return profile.name
    }

    /// Đóng cửa sổ: bỏ mọi tab object rồi ngắt shell.
    public func closeAll() async {
        store.closeAll()
        await shell.disconnect()
    }
}
