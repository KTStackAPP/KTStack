import AppKit
import Combine
import KTDatabasePlugin
import SwiftUI

@MainActor
final class DatabaseWindows {
    private let plugin: KTDatabasePlugin

    private let documentBrowser = PluginWindowController(
        title: "Document Browser",
        autosaveName: "KTStackDocumentEditor",
        minSize: NSSize(width: 720, height: 480),
        defaultSize: NSSize(width: 1000, height: 680)
    )
    private let workspace = PluginWindowController(
        title: "KTStack Database",
        autosaveName: "KTStackDatabaseWorkspace",
        minSize: NSSize(width: 1000, height: 640),
        defaultSize: NSSize(width: 1360, height: 860),
        chrome: .native(tabbingIdentifier: "KTStackDatabase")
    )
    #if DEBUG
        private let sqlDrafts = PluginWindowController(
            title: "SQL Editor Drafts",
            autosaveName: "KTStackSQLEditorDrafts",
            minSize: NSSize(width: 900, height: 560),
            defaultSize: NSSize(width: 1200, height: 760)
        )
    #endif

    // Tiêu đề tab theo tên kết nối của session.
    private var titleBindings: [ObjectIdentifier: AnyCancellable] = [:]

    init(plugin: KTDatabasePlugin) {
        self.plugin = plugin
    }

    func handle(_ route: DatabaseRoute) {
        switch route {
        case .documentBrowser:
            documentBrowser.present(plugin.makeDocumentBrowserView(), onClose: {})
        case let .workspace(profileID):
            openWorkspace(profileID: profileID)
        case .closeDocumentBrowser:
            documentBrowser.close()
        case .closeWorkspace:
            workspace.closeKeyWindow()
        case .runtimes:
            break // AppDelegate.routeDatabase chuyển sang Dashboard Runtimes; không mở cửa sổ DB.
        #if DEBUG
            case .sqlDrafts:
                sqlDrafts.present(plugin.makeSQLDraftsGallery(), onClose: {})
        #endif
        }
    }

    private func openWorkspace(profileID: UUID?) {
        AppActivationPolicy.activateRegular()
        if workspace.allWindows.isEmpty {
            let session = plugin.makeWorkspaceSession()
            workspace.present(
                initial: makeTab(session: session, initialProfileID: profileID),
                makeTab: { [weak self] in self?.makeNewTab() ?? PluginTabContent(content: AnyView(EmptyView())) }
            )
            return
        }

        // Open Database Panel: chỉ đưa cửa sổ hiện có lên trước.
        guard let profileID else {
            workspace.allWindows.first.map { workspace.select($0) }
            return
        }

        // Tab đã nối profile này: chọn nó, không nối trùng.
        if let existing = workspace.window(where: { ($0.identity as? WorkspaceSession)?.connectedProfileID == profileID }) {
            workspace.select(existing)
            return
        }

        // Tab chưa nối: đẩy profile vào rồi chọn.
        if let free = workspace.window(where: { ($0.identity as? WorkspaceSession)?.connectedProfileID == nil }),
           let session = workspace.tabContent(for: free)?.identity as? WorkspaceSession
        {
            session.store.requestActivation(profileID)
            workspace.select(free)
            return
        }

        // Không còn tab trống: tab mới cho profile.
        let session = plugin.makeWorkspaceSession()
        workspace.addTab(makeTab(session: session, initialProfileID: profileID))
    }

    private func makeNewTab() -> PluginTabContent {
        makeTab(session: plugin.makeWorkspaceSession(), initialProfileID: nil)
    }

    private func makeTab(session: WorkspaceSession, initialProfileID: UUID?) -> PluginTabContent {
        let tc = PluginTabContent(
            viewController: plugin.makeWorkspaceSplitController(session: session, initialProfileID: initialProfileID),
            toolbar: plugin.makeWorkspaceToolbar(session: session),
            identity: session,
            shouldClose: { [plugin] in plugin.workspaceShouldClose(session: session) },
            onClose: { [weak self, plugin] in
                plugin.workspaceDidClose(session: session)
                self?.titleBindings[ObjectIdentifier(session)] = nil
            }
        )
        DispatchQueue.main.async { [weak self] in self?.bindTitle(session: session) }
        return tc
    }

    private func bindTitle(session: WorkspaceSession) {
        guard let window = workspace.window(where: { ($0.identity as? WorkspaceSession) === session }) else { return }
        titleBindings[ObjectIdentifier(session)] = session.$title.sink { [weak window] title in
            window?.title = title
        }
    }
}
