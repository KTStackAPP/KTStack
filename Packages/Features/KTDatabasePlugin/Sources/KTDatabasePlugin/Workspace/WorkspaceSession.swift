import Combine
import Foundation
import KTPlatformContracts
import KTPluginKit
import KTStackCore

@MainActor
public final class WorkspaceSession: ObservableObject, Identifiable {
    public let id = UUID()
    public let store: WorkspaceStore
    public let shell: DatabaseV2ViewModel
    let sectionState = DatabaseSectionState()
    let feedback = KTFeedbackCenter()
    let databaseVM: DatabaseViewModel
    let backupSession: BackupSession
    @Published public private(set) var title = "KTStack Database"

    private var cancellables: Set<AnyCancellable> = []

    public init(
        store: WorkspaceStore,
        shell: DatabaseV2ViewModel,
        tools: any DatabaseToolsProviding,
        paths: AppSupportPaths
    ) {
        self.store = store
        self.shell = shell
        databaseVM = DatabaseViewModel(tools: tools)
        backupSession = BackupSession.managed(tools: tools, paths: paths)
        Publishers.CombineLatest3(store.$selectedProfileID, store.$profiles, shell.$selectedDatabase)
            .sink { [weak self] id, profiles, database in
                self?.title = Self.windowTitle(for: id, in: profiles, database: database)
            }
            .store(in: &cancellables)
        store.onSelectDatabase = { [weak self] name in
            self?.selectDatabase(name)
        }
    }

    public var connectedProfileID: UUID? { store.selectedProfileID }
    public var pendingChangeTotal: Int { store.pendingChangeTotal }

    static func windowTitle(for id: UUID?, in profiles: [ConnectionProfile], database: String? = nil) -> String {
        guard let id, let profile = profiles.first(where: { $0.id == id }) else { return "KTStack Database" }
        if let database, !database.isEmpty {
            let isHostOnlyName = profile.name == profile.host || profile.name == "127.0.0.1" || profile.name == "localhost"
            return isHostOnlyName ? database : "\(profile.name) — \(database)"
        }
        return profile.name
    }

    public func closeAll() async {
        store.closeAll()
        await shell.disconnect()
    }

    public func selectDatabase(_ name: String) {
        guard let profileID = store.selectedProfileID ?? shell.activeProfile?.id else { return }
        LastUsedDatabaseStore().setLastDatabase(name, for: profileID)
        Task {
            await shell.select(database: name)
            store.activeDatabase = name
            let key = SchemaKey(profileID: profileID, database: name)
            store.cache(objects: shell.tables, for: key)
            if let activeVM = store.activeVM, activeVM.selectedDatabase != name {
                await activeVM.select(database: name)
            }
        }
    }
}
