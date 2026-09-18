import AppKit
import KTPluginKit

extension WorkspaceSidebar {
    final class SidebarItem: NSObject {
        var node: SidebarNode
        var children: [SidebarItem] = []
        init(node: SidebarNode) {
            self.node = node
        }

        override var hash: Int {
            node.id.hashValue
        }

        override func isEqual(_ object: Any?) -> Bool {
            (object as? SidebarItem)?.node.id == node.id
        }
    }

    final class Coordinator: NSObject, NSOutlineViewDataSource, NSOutlineViewDelegate, NSMenuDelegate {
        var parent: WorkspaceSidebar
        weak var outlineView: NSOutlineView?
        private var roots: [SidebarItem] = []
        private var itemsByID: [String: SidebarItem] = [:]
        private var collapsedIDs: Set<String> = []
        private var applyingSelection = false
        private var lastNodes: [SidebarNode]?

        init(_ parent: WorkspaceSidebar) {
            self.parent = parent
        }

        func rebuild(nodes: [SidebarNode]) {
            guard nodes != lastNodes else { return }
            lastNodes = nodes
            roots = nodes.map { makeItem($0) }
            var live: Set<String> = []
            collect(roots, into: &live)
            itemsByID = itemsByID.filter { live.contains($0.key) }
            outlineView?.reloadData()
            for item in roots where !collapsedIDs.contains(item.node.id) {
                outlineView?.expandItem(item)
            }
        }

        private func makeItem(_ node: SidebarNode) -> SidebarItem {
            let item = itemsByID[node.id] ?? SidebarItem(node: node)
            item.node = node
            item.children = node.children.map { makeItem($0) }
            itemsByID[node.id] = item
            return item
        }

        private func collect(_ items: [SidebarItem], into set: inout Set<String>) {
            for item in items {
                set.insert(item.node.id)
                collect(item.children, into: &set)
            }
        }

        func applySelection(_ id: String?) {
            guard let outlineView else { return }
            applyingSelection = true
            defer { applyingSelection = false }
            guard let id, let item = itemsByID[id] else {
                outlineView.deselectAll(nil)
                return
            }
            let row = outlineView.row(forItem: item)
            if row >= 0 {
                outlineView.selectRowIndexes([row], byExtendingSelection: false)
            }
        }

        func outlineView(_: NSOutlineView, numberOfChildrenOfItem item: Any?) -> Int {
            (item as? SidebarItem)?.children.count ?? roots.count
        }

        func outlineView(_: NSOutlineView, child index: Int, ofItem item: Any?) -> Any {
            (item as? SidebarItem)?.children[index] ?? roots[index]
        }

        func outlineView(_: NSOutlineView, isItemExpandable item: Any) -> Bool {
            !((item as? SidebarItem)?.children.isEmpty ?? true)
        }

        func outlineView(_: NSOutlineView, isGroupItem item: Any) -> Bool {
            (item as? SidebarItem)?.node.isGroup ?? false
        }

        func outlineView(_: NSOutlineView, heightOfRowByItem item: Any) -> CGFloat {
            ((item as? SidebarItem)?.node.isGroup ?? false) ? 24 : 26
        }

        func outlineView(_: NSOutlineView, shouldSelectItem item: Any) -> Bool {
            !((item as? SidebarItem)?.node.isGroup ?? true)
        }

        func outlineView(_: NSOutlineView, viewFor _: NSTableColumn?, item: Any) -> NSView? {
            guard let sidebarItem = item as? SidebarItem else { return nil }
            let node = sidebarItem.node
            let cell = (outlineView?.makeView(withIdentifier: .init("cell"), owner: self) as? SidebarCellView)
                ?? SidebarCellView()
            cell.identifier = .init("cell")
            cell.configure(node: node)
            return cell
        }

        func outlineViewSelectionDidChange(_ notification: Notification) {
            guard !applyingSelection, let outline = notification.object as? NSOutlineView else { return }
            guard outline.selectedRow >= 0,
                  let item = outline.item(atRow: outline.selectedRow) as? SidebarItem else { return }
            switch item.node.kind {
            case .table, .view, .query: parent.onSelectObject(item.node)
            default: break
            }
        }

        func outlineViewItemDidExpand(_ notification: Notification) {
            guard let item = notification.userInfo?["NSObject"] as? SidebarItem else { return }
            collapsedIDs.remove(item.node.id)
        }

        func outlineViewItemDidCollapse(_ notification: Notification) {
            guard let item = notification.userInfo?["NSObject"] as? SidebarItem else { return }
            collapsedIDs.insert(item.node.id)
        }

        @objc
        func handleDoubleClick(_ sender: NSOutlineView) {
            guard sender.clickedRow >= 0,
                  let item = sender.item(atRow: sender.clickedRow) as? SidebarItem else { return }
            switch item.node.kind {
            case .table, .view: parent.onOpenInNewTab(item.node)
            default: break
            }
        }

        func menuNeedsUpdate(_ menu: NSMenu) {
            menu.removeAllItems()
            guard let outline = outlineView, outline.clickedRow >= 0,
                  let item = outline.item(atRow: outline.clickedRow) as? SidebarItem else { return }
            for action in parent.contextActions(item.node) {
                let menuItem = NSMenuItem(title: action.title, action: #selector(runAction(_:)), keyEquivalent: "")
                menuItem.target = self
                menuItem.representedObject = action.handler
                menu.addItem(menuItem)
            }
        }

        @objc
        private func runAction(_ sender: NSMenuItem) {
            (sender.representedObject as? () -> Void)?()
        }
    }
}
