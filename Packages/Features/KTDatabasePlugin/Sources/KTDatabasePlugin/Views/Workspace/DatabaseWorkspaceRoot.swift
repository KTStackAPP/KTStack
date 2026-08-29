import KTPlatformContracts
import KTPluginKit
import SwiftUI

/// Cửa sổ "KTStack Database": sidebar kết nối + cây object (phase 2), content là landing khi chưa
/// nối, DatabaseV2Root khi đã nối (tab theo object hoàn thiện ở phase 3).
struct DatabaseWorkspaceRoot: View {
    @ObservedObject var vm: DatabaseV2ViewModel
    @ObservedObject var workspace: WorkspaceStore
    @ObservedObject var sectionState: DatabaseSectionState
    let engines: any DatabaseEngineManaging
    let lastUsed: LastUsedDatabaseStore
    let initialProfileID: UUID?
    let onClose: () -> Void

    @EnvironmentObject private var store: ConnectionStore
    @AppStorage("KTStack.databaseSidebarVisible") private var sidebarVisible = true
    @State private var filter = ""
    @State private var isConnecting = false
    @State private var editSheet: ConnectionProfile?

    var body: some View {
        HSplitView {
            if sidebarVisible {
                sidebarColumn
                    .frame(minWidth: 232, idealWidth: 240, maxWidth: 340, maxHeight: .infinity)
                    .background(KTEditorTheme.sidebar)
            }
            content
                .frame(minWidth: 640, maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(KTEditorTheme.window)
        .background(sidebarToggle)
        .overlay { modalLayer }
        .sheet(item: $editSheet) { profile in
            AddConnectionSheet(editing: profile)
        }
        .onAppear {
            workspace.startPolling()
            if let id = initialProfileID, !isConnected { activate(profileID: id) }
        }
        .onDisappear { workspace.stopPolling() }
    }

    // MARK: Sidebar

    private var sidebarColumn: some View {
        VStack(spacing: 0) {
            searchField
            Divider().overlay(KTEditorTheme.separator)
            WorkspaceSidebar(
                nodes: nodes,
                selectedNodeID: selectedNodeID,
                statusFor: { workspace.status(for: $0) },
                onActivateConnection: { activate(profileID: $0) },
                onSelectObject: { selectObject($0) },
                onOpenInNewTab: { selectObject($0) },
                contextActions: { contextActions(for: $0) }
            )
            Divider().overlay(KTEditorTheme.separator)
            footer
        }
    }

    private var searchField: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 12))
                .foregroundStyle(KTEditorTheme.label3)
            TextField("Lọc kết nối, bảng…", text: $filter)
                .textFieldStyle(.plain)
                .font(.system(size: 12))
            if !filter.isEmpty {
                Button { filter = "" } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(KTEditorTheme.label3)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(KTEditorTheme.fieldBg, in: RoundedRectangle(cornerRadius: 7))
        .padding(10)
    }

    private var footer: some View {
        HStack(spacing: 6) {
            Text("\(workspace.profiles.count) kết nối · \(currentObjects.count) bảng")
                .font(.system(size: 11))
                .foregroundStyle(KTEditorTheme.label2)
            Spacer(minLength: 0)
            Button { sectionState.connectPresented = true } label: {
                Image(systemName: "plus")
            }
            .buttonStyle(.plain)
            .foregroundStyle(KTEditorTheme.label2)
            .help("Thêm kết nối")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    private var sidebarToggle: some View {
        Button("") { sidebarVisible.toggle() }
            .keyboardShortcut("0", modifiers: .command)
            .opacity(0)
            .frame(width: 0, height: 0)
            .accessibilityHidden(true)
    }

    // MARK: Content

    @ViewBuilder
    private var content: some View {
        if isConnected {
            DatabaseV2Root(vm: vm, onClose: onClose, showsTitlebar: false)
        } else {
            ConnectionLandingView(
                selectedProfile: selectedProfile,
                isConnecting: isConnecting,
                onConnect: connectSelected,
                onNewConnection: { sectionState.connectPresented = true }
            )
        }
    }

    private var modalLayer: some View {
        ZStack {
            if sectionState.connectPresented {
                KTConnectModal(
                    onClose: { sectionState.connectPresented = false },
                    onConnected: { _ in sectionState.connectPresented = false }
                )
                .transition(.opacity)
            }
            if sectionState.newDatabasePresented {
                KTNewDatabaseModal(
                    onClose: { sectionState.newDatabasePresented = false },
                    onCreated: { _ in sectionState.newDatabasePresented = false }
                )
                .transition(.opacity)
            }
        }
        .animation(.easeOut(duration: 0.15), value: sectionState.connectPresented)
        .animation(.easeOut(duration: 0.15), value: sectionState.newDatabasePresented)
    }

    // MARK: Derived state

    private var isConnected: Bool {
        if case .connected = vm.connectionState { return true }
        return false
    }

    private var selectedProfile: ConnectionProfile? {
        guard let id = workspace.selectedProfileID else { return workspace.profiles.first }
        return workspace.profiles.first { $0.id == id }
    }

    private var currentKey: SchemaKey? {
        guard let pid = workspace.selectedProfileID, let db = workspace.activeDatabase, !db.isEmpty else { return nil }
        return SchemaKey(profileID: pid, database: db)
    }

    private var currentObjects: [TableInfo] {
        guard let key = currentKey else { return [] }
        return workspace.cachedObjects(for: key) ?? vm.tables
    }

    private var nodes: [SidebarNode] {
        SidebarNode.build(
            profiles: workspace.profiles,
            selectedProfileID: workspace.selectedProfileID,
            database: workspace.activeDatabase,
            objects: currentObjects,
            favorites: vm.favorites,
            filter: filter
        )
    }

    private var selectedNodeID: String? {
        guard let table = vm.selectedTable, let db = workspace.activeDatabase else { return nil }
        return (table.isView ? "vw." : "tbl.") + db + "." + table.name
    }

    // MARK: Actions

    private func activate(profileID: UUID) {
        guard let profile = workspace.profiles.first(where: { $0.id == profileID }) else { return }
        workspace.selectedProfileID = profileID
        Task { await connectStartingEngine(profile) }
    }

    private func connectSelected() {
        guard let profile = selectedProfile else { return }
        workspace.selectedProfileID = profile.id
        Task { await connectStartingEngine(profile) }
    }

    /// Managed engine chưa chạy thì bật rồi chờ, sau đó mới nối.
    private func connectStartingEngine(_ profile: ConnectionProfile) async {
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

    private func switchDatabase(_ name: String) {
        guard let pid = workspace.selectedProfileID else { return }
        Task {
            await vm.select(database: name)
            await refreshSchema(profileID: pid)
        }
    }

    private func selectObject(_ node: SidebarNode) {
        switch node.kind {
        case let .table(name), let .view(name):
            guard let table = currentObjects.first(where: { $0.name == name }) else { return }
            vm.select(table: table)
            recordRecent(table)
        default:
            break
        }
    }

    private func recordRecent(_ table: TableInfo) {
        guard let pid = workspace.selectedProfileID, let db = workspace.activeDatabase else { return }
        workspace.recentStore.record(
            RecentObject(profileID: pid, database: db, name: table.name, isView: table.isView)
        )
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
        store.add(copy)
    }

    private func contextActions(for node: SidebarNode) -> [SidebarAction] {
        switch node.kind {
        case let .connection(id):
            guard let profile = workspace.profiles.first(where: { $0.id == id }) else { return [] }
            var actions = [SidebarAction(title: "Kết nối") { activate(profileID: id) }]
            if !profile.isManaged {
                actions.append(SidebarAction(title: "Sửa…") { editSheet = profile })
                actions.append(SidebarAction(title: "Nhân bản") { duplicate(profile) })
                actions.append(SidebarAction(title: "Xóa", isDestructive: true) { store.remove(profile) })
            }
            return actions
        case .tablesHeader:
            return vm.databases.map { db in
                SidebarAction(title: db.name) { switchDatabase(db.name) }
            }
        default:
            return []
        }
    }
}
