import Combine
import KTPlatformContracts
import KTPluginKit
import SwiftUI

@MainActor
final class WorkspaceRootModel: ObservableObject {
    let session: WorkspaceSession
    var vm: DatabaseV2ViewModel { session.shell }
    var workspace: WorkspaceStore { session.store }

    let engines: any DatabaseEngineManaging
    let lastUsed: LastUsedDatabaseStore
    var backupSession: BackupSession { session.backupSession }
    var feedback: KTFeedbackCenter { session.feedback }
    var sectionState: DatabaseSectionState { session.sectionState }
    var admin: DatabaseAdminModel { session.admin }
    var documentVM: DocumentViewModel { session.documentVM }
    let connectionStore: ConnectionStore
    let engineInstalled: (DatabaseEngine) -> Bool
    let openRuntimes: (DatabaseEngine) -> Void
    let initialProfileID: UUID?

    @Published var filter = ""
    @Published var isConnecting = false
    @Published var editSheet: ConnectionProfile?
    @Published var showBackups = false
    @Published var pendingCloseTab: PendingCloseTab?
    @Published var confirmDisconnect = false
    private var cancellables = Set<AnyCancellable>()
    struct PendingCloseTab: Identifiable {
        let id: UUID
        let count: Int
    }

    init(
        session: WorkspaceSession,
        engines: any DatabaseEngineManaging,
        lastUsed: LastUsedDatabaseStore,
        connectionStore: ConnectionStore,
        engineInstalled: @escaping (DatabaseEngine) -> Bool,
        openRuntimes: @escaping (DatabaseEngine) -> Void,
        initialProfileID: UUID?
    ) {
        self.session = session
        self.engines = engines
        self.lastUsed = lastUsed
        self.connectionStore = connectionStore
        self.engineInstalled = engineInstalled
        self.openRuntimes = openRuntimes
        self.initialProfileID = initialProfileID
        session.shell.objectWillChange.sink { [weak self] _ in self?.objectWillChange.send() }.store(in: &cancellables)
        session.store.objectWillChange.sink { [weak self] _ in self?.objectWillChange.send() }.store(in: &cancellables)
    }

    var isConnected: Bool {
        if case .connected = vm.connectionState { return true }
        return false
    }

    var selectedProfile: ConnectionProfile? {
        guard let id = workspace.selectedProfileID else { return workspace.profiles.first }
        return workspace.profiles.first { $0.id == id }
    }

    private var currentKey: SchemaKey? {
        guard let pid = workspace.selectedProfileID, let db = workspace.activeDatabase, !db.isEmpty else { return nil }
        return SchemaKey(profileID: pid, database: db)
    }

    var currentObjects: [TableInfo] {
        guard let key = currentKey else { return [] }
        return workspace.cachedObjects(for: key) ?? vm.tables
    }

    var nodes: [SidebarNode] {
        SidebarNode.build(objects: currentObjects, favorites: vm.favorites, filter: filter)
    }

    var selectedNodeID: String? {
        guard let session = workspace.activeSession,
              case let .table(_, _, table) = session.kind else { return nil }
        return (table.isView ? "vw." : "tbl.") + table.name
    }

    func activate(profileID: UUID, database: String? = nil) {
        guard let profile = workspace.profiles.first(where: { $0.id == profileID }) else { return }
        workspace.selectedProfileID = profileID
        lastUsed.setLastProfileID(profileID)
        if let database, !database.isEmpty {
            lastUsed.setLastDatabase(database, for: profileID)
        }
        Task { await connectStartingEngine(profile) }
    }

    func connectStartingEngine(_ profile: ConnectionProfile) async {
        let isLocalEngine = profile.isManaged || ConnectionProfile.isLoopback(profile.host)
        if isLocalEngine, let engine = profile.kind.engine, !engines.isRunning(engine) {
            engines.toggle(engine)
            await waitForEngine(engine, timeout: 15)
        }
        await connect(profile)
    }

    private func connect(_ profile: ConnectionProfile) async {
        isConnecting = true
        defer { isConnecting = false }
        await vm.connect(profile: profile)
        guard case .connected = vm.connectionState else { return }
        Task { await admin.select(profile: profile) }
        if let last = lastUsed.lastDatabase(for: profile.id),
           vm.databases.contains(where: { $0.name == last }), last != vm.selectedDatabase {
            await vm.select(database: last)
        } else if vm.selectedDatabase == nil, let first = vm.databases.first?.name {
            await vm.select(database: first)
        }
        await refreshSchema(profileID: profile.id)
        if workspace.tabs.isEmpty, let firstTable = currentObjects.first {
            openTableDirectly(firstTable)
        }
    }

    private func openTableDirectly(_ table: TableInfo) {
        guard let pid = workspace.selectedProfileID, let db = workspace.activeDatabase else { return }
        workspace.openTable(table, profileID: pid, database: db, forceNewTab: false)
        recordRecent(table)
    }

    private func waitForEngine(_ engine: DatabaseEngine, timeout: TimeInterval) async {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if engines.isRunning(engine) { return }
            try? await Task.sleep(nanoseconds: 500_000_000)
        }
    }

    func refreshSchema(profileID: UUID) async {
        guard let db = vm.selectedDatabase, !db.isEmpty else {
            workspace.activeDatabase = nil
            return
        }
        workspace.activeDatabase = db
        lastUsed.setLastDatabase(db, for: profileID)
        let key = SchemaKey(profileID: profileID, database: db)
        workspace.invalidate(key)
        _ = try? await workspace.schema(for: key)
    }

    func selectDatabase(_ name: String) {
        session.selectDatabase(name)
    }

    func selectObject(_ node: SidebarNode, forceNewTab: Bool) {
        switch node.kind {
        case let .table(name), let .view(name):
            guard let table = currentObjects.first(where: { $0.name == name }),
                  let pid = workspace.selectedProfileID, let db = workspace.activeDatabase
            else { return }
            workspace.openTable(table, profileID: pid, database: db, forceNewTab: forceNewTab)
            recordRecent(table)
        default:
            break
        }
    }

    func openQueryTab() {
        guard let pid = workspace.selectedProfileID, let db = workspace.activeDatabase else { return }
        workspace.openQuery(profileID: pid, database: db)
    }

    func requestCloseTab(_ id: UUID) {
        if case let .needsConfirmation(count) = workspace.closeTab(id) {
            pendingCloseTab = PendingCloseTab(id: id, count: count)
        }
    }

    func requestCloseActiveTab() {
        guard let id = workspace.activeTabID else { return }
        requestCloseTab(id)
    }

    func requestDisconnect() {
        if workspace.pendingChangeTotal > 0 { confirmDisconnect = true } else { performDisconnect() }
    }

    func performDisconnect() {
        Task {
            await session.closeAll()
            workspace.selectedProfileID = nil
            workspace.activeDatabase = nil
        }
    }
}
