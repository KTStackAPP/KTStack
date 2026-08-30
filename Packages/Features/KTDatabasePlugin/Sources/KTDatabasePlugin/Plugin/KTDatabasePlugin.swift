import AppKit
import KTPlatformContracts
import KTPluginKit
import KTStackCore
import SwiftUI

public final class KTDatabasePlugin: KTStackPlugin, PluginLifecycle, SectionActivationObserving {
    public let descriptor = PluginDescriptor(id: "database", title: "Database", systemImage: "cylinder.split.1x2")

    private let tools: any DatabaseToolsProviding
    let engines: any DatabaseEngineManaging
    let sites: any SiteCatalogManaging
    private let paths: AppSupportPaths
    private let route: @MainActor (DatabaseRoute) -> Void
    private let modals: KTModalPresenter

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
    @MainActor lazy var recentObjectStore = RecentObjectStore(paths: paths)
    @MainActor lazy var lastUsedDatabaseStore = LastUsedDatabaseStore()

    /// Mỗi cửa sổ/tab một session: shell nối riêng + store tab object riêng, dùng chung preset/history/favorite.
    @MainActor
    public func makeWorkspaceSession() -> WorkspaceSession {
        let shell = makeShellViewModel()
        weak var weakStore: WorkspaceStore?
        let store = WorkspaceStore(
            connectionStore: connectionStore,
            reachability: reachability,
            recentStore: recentObjectStore,
            objectLoader: { [weak shell] _ in shell?.tables ?? [] },
            makeViewModel: { [tools, filterPresetStore, queryHistoryStore, queryFavoriteStore] in
                let vm = DatabaseV2ViewModel(
                    tools: tools, presetStore: filterPresetStore,
                    historyStore: queryHistoryStore, favoriteStore: queryFavoriteStore
                )
                vm.onSchemaChanged = { profileID, database in
                    weakStore?.refreshSchema(profileID: profileID, database: database)
                }
                return vm
            }
        )
        weakStore = store
        return WorkspaceSession(store: store, shell: shell, tools: tools, paths: paths)
    }

    @MainActor
    private func makeShellViewModel() -> DatabaseV2ViewModel {
        DatabaseV2ViewModel(
            tools: tools, presetStore: filterPresetStore,
            historyStore: queryHistoryStore, favoriteStore: queryFavoriteStore
        )
    }
    @MainActor let feedback = KTFeedbackCenter()
    /// Modal chạy trong cửa sổ con riêng nên cần host feedback riêng, không dùng chung với tab.
    @MainActor let modalFeedback = KTFeedbackCenter()

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
        sites: any SiteCatalogManaging,
        modals: KTModalPresenter,
        paths: AppSupportPaths = AppSupportPaths(),
        route: @escaping @MainActor (DatabaseRoute) -> Void
    ) {
        self.tools = tools
        self.engines = engines
        self.sites = sites
        self.modals = modals
        self.paths = paths
        self.route = route
    }

    @MainActor
    public func makeContentView() -> AnyView {
        AnyView(
            DatabaseSectionContainer(plugin: self)
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

    /// Cửa sổ "KTStack Database": khung NSSplitViewController ba pane, mỗi cửa sổ/tab một session.
    @MainActor
    public func makeWorkspaceSplitController(session: WorkspaceSession, initialProfileID: UUID?) -> NSViewController {
        let model = WorkspaceRootModel(
            session: session,
            engines: engines,
            lastUsed: lastUsedDatabaseStore,
            backupSession: session.backupSession,
            feedback: session.feedback,
            sectionState: session.sectionState,
            connectionStore: connectionStore,
            databaseVM: session.databaseVM,
            engineInstalled: { [weak self] engine in self?.engineInstalled(engine) ?? false },
            openRuntimes: { [route] engine in route(.runtimes(engine)) },
            initialProfileID: initialProfileID
        )
        return WorkspaceSplitController(model: model)
    }

    /// Nội dung NSToolbar unified của cửa sổ workspace, đọc tab đang mở từ store của session.
    @MainActor
    public func makeWorkspaceToolbar(session: WorkspaceSession) -> AnyView {
        AnyView(WorkspaceToolbar(workspace: session.store))
    }

    #if DEBUG
        @MainActor
        public func makeSQLDraftsGallery() -> AnyView {
            AnyView(SQLEditorDraftsGallery())
        }
    #endif

    /// Trang kết nối sống trong cửa sổ con của shell, nên phải tự bơm lại environment của tab.
    @MainActor
    func presentConnections(mode: ConnectionsModal.Mode = .list) {
        modals.present(id: "database.connections") { [self] in
            ConnectionsModal(plugin: self, mode: mode)
                .environmentObject(connectionStore)
                .environmentObject(databaseVM)
                .environmentObject(documentVM)
        }
    }

    @MainActor
    func dismissConnections() {
        modals.dismiss()
    }

    @MainActor
    var importableSites: [SiteSummary] {
        sites.catalog.sites.filter { !$0.path.isEmpty }
    }

    /// "Open Database Panel": mở workspace không chọn sẵn profile.
    @MainActor
    func openDatabasePanel() {
        route(.workspace(profileID: nil))
    }

    /// Open trên một hàng kết nối: mở workspace và chọn sẵn profile đó.
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
    public func workspaceDidClose(session: WorkspaceSession) {
        Task { await session.closeAll() }
    }

    /// Đóng tab cửa sổ: gom pending mọi tab object của session, hỏi một lần với tổng số.
    @MainActor
    public func workspaceShouldClose(session: WorkspaceSession) -> Bool {
        let pending = session.pendingChangeTotal
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
        presentConnections()
    }

    @MainActor
    public func sectionDidDeactivate() {
        reachability.stop(owner: "section")
        dismissConnections()
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

    var body: some View {
        DatabaseBrandPage(
            onConnections: { plugin.presentConnections() },
            onCreate: { plugin.presentConnections(mode: .create) },
            onOpenPanel: { plugin.openDatabasePanel() }
        )
    }
}
