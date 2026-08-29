import AppKit
import KTPlatformContracts
import KTPluginKit
import KTStackCore
import SwiftUI

public final class KTDatabasePlugin: KTStackPlugin, PluginLifecycle, SectionActivationObserving {
    public let descriptor = PluginDescriptor(id: "database", title: "Database", systemImage: "cylinder.split.1x2")

    private let tools: any DatabaseToolsProviding
    let engines: any DatabaseEngineManaging
    private let paths: AppSupportPaths
    private let route: @MainActor (DatabaseRoute) -> Void

    @MainActor public lazy var connectionStore = ConnectionStore(
        storeURL: paths.config
            .appendingPathComponent("database", isDirectory: true)
            .appendingPathComponent("connections.json")
    )
    @MainActor lazy var databaseVM = DatabaseViewModel(tools: tools)
    @MainActor lazy var documentVM = DocumentViewModel(tools: tools)
    @MainActor lazy var filterPresetStore = FilterPresetStore(
        storeURL: paths.config
            .appendingPathComponent("database", isDirectory: true)
            .appendingPathComponent("filter-presets.json")
    )
    @MainActor lazy var queryHistoryStore = QueryHistoryStore(paths: paths)
    @MainActor lazy var queryFavoriteStore = QueryFavoriteStore(paths: paths)
    @MainActor lazy var v2VM = DatabaseV2ViewModel(
        tools: tools, presetStore: filterPresetStore,
        historyStore: queryHistoryStore, favoriteStore: queryFavoriteStore
    )
    @MainActor lazy var recentObjectStore = RecentObjectStore(paths: paths)
    @MainActor lazy var lastUsedDatabaseStore = LastUsedDatabaseStore()
    @MainActor lazy var workspaceStore = WorkspaceStore(
        connectionStore: connectionStore,
        reachability: reachability,
        recentStore: recentObjectStore,
        objectLoader: { [weak self] _ in self?.v2VM.tables ?? [] },
        makeViewModel: { [weak self, tools] in self?.makeTabViewModel() ?? DatabaseV2ViewModel(tools: tools) }
    )

    /// Mỗi tab một VM riêng nhưng dùng chung preset/history/favorite store (ghi file qua store serial).
    @MainActor
    func makeTabViewModel() -> DatabaseV2ViewModel {
        let vm = DatabaseV2ViewModel(
            tools: tools, presetStore: filterPresetStore,
            historyStore: queryHistoryStore, favoriteStore: queryFavoriteStore
        )
        vm.onSchemaChanged = { [weak self] profileID, database in
            self?.workspaceStore.refreshSchema(profileID: profileID, database: database)
        }
        return vm
    }
    @MainActor lazy var backupSession = BackupSession.managed(tools: tools, paths: paths)
    @MainActor let feedback = KTFeedbackCenter()
    @MainActor let sectionState = DatabaseSectionState()

    @MainActor lazy var reachability: ServerReachabilityService = {
        let service = ServerReachabilityService()
        service.configure(
            profiles: { [weak self] in self?.connectionStore.profiles ?? [] },
            managedRunning: { [weak self] kind in
                guard let self, let engine = kind.engine else { return false }
                return engines.isRunning(engine)
            }
        )
        return service
    }()

    public init(
        tools: any DatabaseToolsProviding,
        engines: any DatabaseEngineManaging,
        paths: AppSupportPaths = AppSupportPaths(),
        route: @escaping @MainActor (DatabaseRoute) -> Void
    ) {
        self.tools = tools
        self.engines = engines
        self.paths = paths
        self.route = route
    }

    @MainActor
    public func makeContentView() -> AnyView {
        AnyView(
            DatabaseSectionContainer(plugin: self, state: sectionState)
                .environmentObject(connectionStore)
                .environmentObject(databaseVM)
                .environmentObject(documentVM)
                .ktFeedbackHost(feedback)
        )
    }

    @MainActor
    public func makeDocumentBrowserView() -> AnyView {
        AnyView(DocumentSectionContent(engines: engines).environmentObject(documentVM))
    }

    /// Cửa sổ "KTStack Database": v2VM là connection shell (sidebar/landing/đổi DB), mỗi tab một VM riêng.
    @MainActor
    public func makeWorkspaceView(profileID: UUID?) -> AnyView {
        AnyView(
            DatabaseWorkspaceRoot(
                vm: v2VM,
                workspace: workspaceStore,
                sectionState: sectionState,
                engines: engines,
                lastUsed: lastUsedDatabaseStore,
                backupSession: backupSession,
                feedback: feedback,
                initialProfileID: profileID,
                onClose: { [route] in route(.closeWorkspace) }
            )
            .environmentObject(connectionStore)
            .environmentObject(databaseVM)
            .environmentObject(documentVM)
            .ktFeedbackHost(feedback)
        )
    }

    /// Nội dung NSToolbar unified của cửa sổ workspace, đọc tab đang mở từ workspaceStore.
    @MainActor
    public func makeWorkspaceToolbar() -> AnyView {
        AnyView(WorkspaceToolbar(workspace: workspaceStore))
    }

    #if DEBUG
        @MainActor
        public func makeSQLDraftsGallery() -> AnyView {
            AnyView(SQLEditorDraftsGallery())
        }
    #endif

    /// Overview "Open Database Panel": mở workspace không chọn sẵn profile.
    @MainActor
    func openDatabasePanel() {
        route(.workspace(profileID: nil))
    }

    /// Overview engine row Open: mở workspace và chọn sẵn engine tương ứng.
    @MainActor
    func openWorkspace(_ profile: ConnectionProfile) {
        route(.workspace(profileID: profile.id))
    }

    @MainActor
    func openDocumentBrowser(_: ConnectionProfile) {
        route(.documentBrowser)
    }

    @MainActor
    func engineInstalled(_ engine: DatabaseEngine) -> Bool {
        tools.isInstalled(engine)
    }

    @MainActor
    public func workspaceDidClose() {
        workspaceStore.closeAll()
        Task { await v2VM.disconnect() }
    }

    /// Đóng cửa sổ workspace: gom pending mọi tab, hỏi một lần với tổng số.
    @MainActor
    public func workspaceShouldClose() -> Bool {
        let pending = workspaceStore.pendingChangeTotal
        guard pending > 0 else { return true }
        let alert = NSAlert()
        alert.messageText = "Discard pending changes?"
        alert.informativeText =
            "\(pending) pending change\(pending == 1 ? "" : "s") across open tabs will be discarded if you close. Commit or undo first to keep them."
        alert.addButton(withTitle: "Discard & Close")
        alert.addButton(withTitle: "Cancel")
        return alert.runModal() == .alertFirstButtonReturn
    }

    @MainActor
    func closeDocumentBrowser() {
        route(.closeDocumentBrowser)
    }

    // SectionActivationObserving: keep-alive shell ẩn view nên onDisappear không fire khi đổi tab.
    @MainActor
    public func sectionDidActivate() {
        reachability.start(owner: "section")
    }

    @MainActor
    public func sectionDidDeactivate() {
        reachability.stop(owner: "section")
    }

    /// PluginLifecycle
    public func start() async {}

    /// Chạy trong quit khi coordinator block main; chỉ hạ NIO loop, không hop @MainActor.
    public func shutdown() async {
        try? await EventLoopProvider.shared.shutdown()
    }
}

@MainActor
struct DatabaseSectionContainer: View {
    let plugin: KTDatabasePlugin
    @ObservedObject var state: DatabaseSectionState

    var body: some View {
        DatabaseOverviewView(plugin: plugin)
            .overlay { modalLayer }
    }

    private var modalLayer: some View {
        ZStack {
            if state.connectPresented {
                KTConnectModal(
                    onClose: { state.connectPresented = false },
                    onConnected: { name in
                        state.connectPresented = false
                        plugin.feedback.toast("Connected to \(name)")
                    }
                )
                .transition(.opacity)
            }
        }
        .animation(.easeOut(duration: 0.15), value: state.connectPresented)
    }
}
