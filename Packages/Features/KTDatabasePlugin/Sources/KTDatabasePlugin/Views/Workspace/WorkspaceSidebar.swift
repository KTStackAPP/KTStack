import AppKit
import KTPluginKit
import SwiftUI

struct SidebarAction {
    let title: String
    var isDestructive = false
    let handler: () -> Void
}

struct WorkspaceSidebar: NSViewRepresentable {
    let nodes: [SidebarNode]
    let selectedNodeID: String?
    var onSelectObject: (SidebarNode) -> Void
    var onOpenInNewTab: (SidebarNode) -> Void
    var contextActions: (SidebarNode) -> [SidebarAction]

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeNSView(context: Context) -> NSScrollView {
        let outline = NSOutlineView()
        outline.headerView = nil
        outline.rowSizeStyle = .custom
        outline.rowHeight = 24
        outline.style = .sourceList
        outline.focusRingType = .none
        outline.indentationPerLevel = 14
        outline.backgroundColor = .clear
        outline.floatsGroupRows = false

        let column = NSTableColumn(identifier: .init("main"))
        column.resizingMask = .autoresizingMask
        outline.addTableColumn(column)
        outline.outlineTableColumn = column

        outline.dataSource = context.coordinator
        outline.delegate = context.coordinator
        outline.target = context.coordinator
        outline.doubleAction = #selector(Coordinator.handleDoubleClick(_:))

        let menu = NSMenu()
        menu.delegate = context.coordinator
        outline.menu = menu

        context.coordinator.outlineView = outline
        context.coordinator.rebuild(nodes: nodes)

        let scroll = NSScrollView()
        scroll.documentView = outline
        scroll.hasVerticalScroller = true
        scroll.drawsBackground = false
        scroll.automaticallyAdjustsContentInsets = false
        return scroll
    }

    func updateNSView(_: NSScrollView, context: Context) {
        context.coordinator.parent = self
        context.coordinator.rebuild(nodes: nodes)
        context.coordinator.applySelection(selectedNodeID)
    }
}
