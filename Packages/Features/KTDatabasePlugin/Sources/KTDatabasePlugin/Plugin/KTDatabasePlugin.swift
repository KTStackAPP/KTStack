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
    @MainActor lazy var v2VM = DatabaseV2ViewModel(tools: tools)
    @MainActor lazy var backupSession = BackupSession.managed(tools: tools, paths: paths)
    @MainActor let feedback = KTFeedbackCenter()
    @MainActor let sectionState = DatabaseSectionState()

    @MainActor lazy var reachability: ServerReachabilityService = {
        let service = ServerReachabilityService()
        service.configure(
            profiles: { [weak self] in self?.connectionStore.profiles ?? [] },
            managedRunning: { [weak self] kind in
                guard let self, let engine = kind.engine else { return false }
                return self.engines.isRunning(engine)
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
    public func makeSQLEditorView() -> AnyView {
        AnyView(DatabaseV2Root(vm: v2VM, onClose: { [route] in route(.closeSQLEditor) }))
    }

    @MainActor
    public func makeDocumentBrowserView() -> AnyView {
        AnyView(DocumentSectionContent(engines: engines).environmentObject(documentVM))
    }

    #if DEBUG
        @MainActor
        public func makeSQLDraftsGallery() -> AnyView {
            AnyView(SQLEditorDraftsGallery())
        }
    #endif

    @MainActor
    func openSQLEditor(_ profile: ConnectionProfile) {
        route(.sqlEditor)
        Task { await v2VM.connect(profile: profile) }
    }

    @MainActor
    func openDocumentBrowser(_: ConnectionProfile) {
        route(.documentBrowser)
    }

    @MainActor func closeSQLEditor() { route(.closeSQLEditor) }
    @MainActor func closeDocumentBrowser() { route(.closeDocumentBrowser) }

    @MainActor
    public func sqlEditorDidClose() {
        Task { await v2VM.disconnect() }
    }

    // SectionActivationObserving: keep-alive shell ẩn view nên onDisappear không fire khi đổi tab.
    @MainActor public func sectionDidActivate() { reachability.start() }
    @MainActor public func sectionDidDeactivate() { reachability.stop() }

    // PluginLifecycle
    public func start() async {}

    // Chạy trong quit khi coordinator block main; chỉ hạ NIO loop, không hop @MainActor.
    public func shutdown() async {
        try? await EventLoopProvider.shared.shutdown()
    }
}

@MainActor
struct DatabaseSectionContainer: View {
    let plugin: KTDatabasePlugin
    @ObservedObject var state: DatabaseSectionState

    var body: some View {
        DatabaseSectionView(plugin: plugin)
            .overlay { modalLayer }
    }

    @ViewBuilder
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
            if state.newDatabasePresented {
                KTNewDatabaseModal(
                    onClose: { state.newDatabasePresented = false },
                    onCreated: { name in
                        state.newDatabasePresented = false
                        plugin.feedback.toast("Database “\(name)” created")
                    }
                )
                .transition(.opacity)
            }
        }
        .animation(.easeOut(duration: 0.15), value: state.connectPresented)
        .animation(.easeOut(duration: 0.15), value: state.newDatabasePresented)
    }
}
