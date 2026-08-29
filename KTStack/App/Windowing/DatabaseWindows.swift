import AppKit
import KTDatabasePlugin

@MainActor
final class DatabaseWindows {
    private let plugin: KTDatabasePlugin

    private let sqlEditor = PluginWindowController(
        title: "SQL Editor",
        autosaveName: "KTStackSQLEditorV2",
        minSize: NSSize(width: 900, height: 560),
        defaultSize: NSSize(width: 1200, height: 760)
    )
    private let documentBrowser = PluginWindowController(
        title: "Document Browser",
        autosaveName: "KTStackDocumentEditor",
        minSize: NSSize(width: 720, height: 480),
        defaultSize: NSSize(width: 1000, height: 680)
    )
    private let workspace = PluginWindowController(
        title: "KTStack Database",
        autosaveName: "KTStackDatabaseWorkspace",
        minSize: NSSize(width: 960, height: 600),
        defaultSize: NSSize(width: 1280, height: 800),
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

    init(plugin: KTDatabasePlugin) {
        self.plugin = plugin
    }

    func handle(_ route: DatabaseRoute) {
        switch route {
        case .sqlEditor:
            sqlEditor.present(
                plugin.makeSQLEditorView(),
                onClose: { [plugin] in plugin.sqlEditorDidClose() },
                shouldClose: { [plugin] in plugin.sqlEditorShouldClose() }
            )
        case .documentBrowser:
            documentBrowser.present(plugin.makeDocumentBrowserView(), onClose: {})
        case let .workspace(profileID):
            workspace.present(
                plugin.makeWorkspaceView(profileID: profileID),
                toolbar: plugin.makeWorkspaceToolbar(),
                onClose: { [plugin] in plugin.workspaceDidClose() },
                shouldClose: { [plugin] in plugin.workspaceShouldClose() }
            )
        case .closeSQLEditor:
            sqlEditor.close()
        case .closeDocumentBrowser:
            documentBrowser.close()
        case .closeWorkspace:
            workspace.close()
        #if DEBUG
            case .sqlDrafts:
                sqlDrafts.present(plugin.makeSQLDraftsGallery(), onClose: {})
        #endif
        }
    }
}
