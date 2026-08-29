import Combine
import KTPlatformContracts
import KTPluginKit
import SwiftUI

/// State + hành động của cửa sổ workspace, dùng chung cho ba pane (sidebar/content/inspector) của
/// NSSplitViewController. Trước đây nằm trong DatabaseWorkspaceRoot; tách ra để ba hosting controller
/// cùng quan sát một nguồn.
@MainActor
final class WorkspaceRootModel: ObservableObject {
    let session: WorkspaceSession
    var vm: DatabaseV2ViewModel { session.shell }
    var workspace: WorkspaceStore { session.store }

    let engines: any DatabaseEngineManaging
    let lastUsed: LastUsedDatabaseStore
    let backupSession: BackupSession
    let feedback: KTFeedbackCenter
    let sectionState: DatabaseSectionState
    let connectionStore: ConnectionStore
    let databaseVM: DatabaseViewModel
    let engineInstalled: (DatabaseEngine) -> Bool
    let openRuntimes: (DatabaseEngine) -> Void
    let initialProfileID: UUID?

    @Published var filter = ""
    @Published var isConnecting = false
    @Published var editSheet: ConnectionProfile?
    @Published var showBackups = false
    @Published var pendingCloseTab: PendingCloseTab?
    @Published var confirmDisconnect = false

    struct PendingCloseTab: Identifiable {
        let id: UUID
        let count: Int
    }

    init(
        session: WorkspaceSession,
        engines: any DatabaseEngineManaging,
        lastUsed: LastUsedDatabaseStore,
        backupSession: BackupSession,
        feedback: KTFeedbackCenter,
        sectionState: DatabaseSectionState,
        connectionStore: ConnectionStore,
        databaseVM: DatabaseViewModel,
        engineInstalled: @escaping (DatabaseEngine) -> Bool,
        openRuntimes: @escaping (DatabaseEngine) -> Void,
        initialProfileID: UUID?
    ) {
        self.session = session
        self.engines = engines
        self.lastUsed = lastUsed
        self.backupSession = backupSession
        self.feedback = feedback
        self.sectionState = sectionState
        self.connectionStore = connectionStore
        self.databaseVM = databaseVM
        self.engineInstalled = engineInstalled
        self.openRuntimes = openRuntimes
        self.initialProfileID = initialProfileID
    }

    // MARK: Derived

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

    // MARK: Actions

    func activate(profileID: UUID) {
        guard let profile = workspace.profiles.first(where: { $0.id == profileID }) else { return }
        workspace.selectedProfileID = profileID
        Task { await connectStartingEngine(profile) }
    }

    /// Managed engine chưa chạy thì bật rồi chờ, sau đó mới nối.
    func connectStartingEngine(_ profile: ConnectionProfile) async {
        if profile.isManaged, let engine = profile.kind.engine, !engines.isRunning(engine) {
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
        if let last = lastUsed.lastDatabase(for: profile.id),
           vm.databases.contains(where: { $0.name == last }), last != vm.selectedDatabase
        {
            await vm.select(database: last)
        }
        await refreshSchema(profileID: profile.id)
    }

    private func waitForEngine(_ engine: DatabaseEngine, timeout: TimeInterval) async {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if engines.isRunning(engine) { return }
            try? await Task.sleep(nanoseconds: 500_000_000)
        }
    }

    private func refreshSchema(profileID: UUID) async {
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

    /// Ngắt kết nối tab hiện tại: hỏi discard nếu còn pending, rồi đóng shell + tab và về trang kết nối.
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

    private func recordRecent(_ table: TableInfo) {
        guard let pid = workspace.selectedProfileID, let db = workspace.activeDatabase else { return }
        workspace.recentStore.record(
            RecentObject(profileID: pid, database: db, name: table.name, isView: table.isView)
        )
    }

    /// Trang kết nối: nối profile, chọn đúng database rồi mở lại bảng gần đây.
    func openRecent(_ object: RecentObject) {
        guard let profile = workspace.profiles.first(where: { $0.id == object.profileID }) else { return }
        workspace.selectedProfileID = profile.id
        Task {
            await connectStartingEngine(profile)
            guard isConnected else { return }
            if vm.selectedDatabase != object.database,
               vm.databases.contains(where: { $0.name == object.database })
            {
                await vm.select(database: object.database)
                await refreshSchema(profileID: profile.id)
            }
            if let table = currentObjects.first(where: { $0.name == object.name }) {
                workspace.openTable(table, profileID: profile.id, database: object.database, forceNewTab: false)
            }
        }
    }

    func profileContextActions(_ profile: ConnectionProfile) -> [SidebarAction] {
        var actions = [
            SidebarAction(title: "Backup…") { [weak self] in self?.backupProfile(profile) },
            SidebarAction(title: "Restore…") { [weak self] in self?.restoreProfile(profile) },
        ]
        if !profile.isManaged {
            actions.append(SidebarAction(title: "Sửa…") { [weak self] in self?.editSheet = profile })
            actions.append(SidebarAction(title: "Nhân bản") { [weak self] in self?.duplicate(profile) })
            actions.append(SidebarAction(title: "Xóa", isDestructive: true) { [weak self] in
                self?.connectionStore.remove(profile)
            })
        }
        return actions
    }

    // Backup/New Database chạy trên databaseVM (v1), nối riêng với tab editor (v2).
    func presentBackups() {
        guard let profile = selectedProfile else { return }
        Task { if await ensureBackupConnection(profile) { showBackups = true } }
    }

    func presentNewDatabase() {
        guard let profile = selectedProfile else { return }
        Task { if await ensureBackupConnection(profile) { sectionState.newDatabasePresented = true } }
    }

    private func backupProfile(_ profile: ConnectionProfile) {
        Task {
            guard await ensureBackupConnection(profile) else { return }
            let set = await databaseVM.backupAllDatabases(session: backupSession)
            if set != nil { feedback.toast("Backed up “\(profile.name)”") }
        }
    }

    private func restoreProfile(_ profile: ConnectionProfile) {
        Task { if await ensureBackupConnection(profile) { showBackups = true } }
    }

    private func ensureBackupConnection(_ profile: ConnectionProfile) async -> Bool {
        if databaseVM.selectedProfile?.id == profile.id, databaseVM.connection == .connected { return true }
        await databaseVM.select(profile: profile)
        if databaseVM.connection == .connected { return true }
        if case let .failed(error) = databaseVM.connection { feedback.toast(error.message) }
        return false
    }

    private func duplicate(_ profile: ConnectionProfile) {
        let copy = ConnectionProfile(
            name: "\(profile.name) copy",
            kind: profile.kind,
            host: profile.host,
            port: profile.port,
            user: profile.user,
            database: profile.database,
            filePath: profile.filePath,
            tlsMode: profile.tlsMode,
            readOnly: profile.readOnly
        )
        connectionStore.add(copy)
    }
}
