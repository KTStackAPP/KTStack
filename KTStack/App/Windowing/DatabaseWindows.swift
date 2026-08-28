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
        case .closeSQLEditor:
            sqlEditor.close()
        case .closeDocumentBrowser:
            documentBrowser.close()
        #if DEBUG
            case .sqlDrafts:
                sqlDrafts.present(plugin.makeSQLDraftsGallery(), onClose: {})
        #endif
        }
    }
}
