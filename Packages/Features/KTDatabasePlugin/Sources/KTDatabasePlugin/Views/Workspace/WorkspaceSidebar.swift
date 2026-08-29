import AppKit
import KTPluginKit
import SwiftUI

struct SidebarAction {
    let title: String
    var isDestructive = false
    let handler: () -> Void
}

/// Sidebar ảo hoá bằng NSOutlineView: 1000+ bảng cuộn mượt (SwiftUI List/ForEach thì không).
/// Cây do SidebarNode phát; chọn/double-click/context menu đổi thành closure sang SwiftUI.
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

        /// Dựng lại cây, tái dùng SidebarItem theo id để NSOutlineView giữ expand/selection.
        /// Bỏ qua reload khi cây không đổi: tick trạng thái engine không được reload cả bảng.
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

        // MARK: DataSource

        func outlineView(_: NSOutlineView, numberOfChildrenOfItem item: Any?) -> Int {
            (item as? SidebarItem)?.children.count ?? roots.count
        }

        func outlineView(_: NSOutlineView, child index: Int, ofItem item: Any?) -> Any {
            (item as? SidebarItem)?.children[index] ?? roots[index]
        }

        func outlineView(_: NSOutlineView, isItemExpandable item: Any) -> Bool {
            !((item as? SidebarItem)?.children.isEmpty ?? true)
        }

        // MARK: Delegate

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

        // MARK: Context menu

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

// Cell: icon + tên object, hoặc header nhóm với số lượng ở phải.
final class SidebarCellView: NSTableCellView {
    private let icon = NSImageView()
    private let label = NSTextField(labelWithString: "")
    private let count = NSTextField(labelWithString: "")

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setup()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError()
    }

    private func setup() {
        icon.translatesAutoresizingMaskIntoConstraints = false
        icon.contentTintColor = NSColor(KTEditorTheme.label2)
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = .systemFont(ofSize: 13)
        label.lineBreakMode = .byTruncatingTail
        label.textColor = NSColor(KTEditorTheme.label)
        count.translatesAutoresizingMaskIntoConstraints = false
        count.font = .monospacedDigitSystemFont(ofSize: 10.5, weight: .regular)
        count.textColor = NSColor(KTEditorTheme.label3)
        count.alignment = .right

        addSubview(icon)
        addSubview(label)
        addSubview(count)
        textField = label
        imageView = icon

        NSLayoutConstraint.activate([
            icon.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 4),
            icon.centerYAnchor.constraint(equalTo: centerYAnchor),
            icon.widthAnchor.constraint(equalToConstant: 16),
            icon.heightAnchor.constraint(equalToConstant: 16),
            label.leadingAnchor.constraint(equalTo: icon.trailingAnchor, constant: 6),
            label.centerYAnchor.constraint(equalTo: centerYAnchor),
            count.leadingAnchor.constraint(greaterThanOrEqualTo: label.trailingAnchor, constant: 6),
            count.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -10),
            count.centerYAnchor.constraint(equalTo: centerYAnchor),
        ])
    }

    func configure(node: SidebarNode) {
        label.stringValue = node.title
        let weight: NSFont.Weight = node.isGroup ? .semibold : .regular
        let size: CGFloat = node.isGroup ? 11 : 13
        label.font = .systemFont(ofSize: size, weight: weight)
        label.textColor = NSColor(node.isGroup ? KTEditorTheme.label2 : KTEditorTheme.label)
        icon.image = NSImage(systemSymbolName: node.systemImage, accessibilityDescription: nil)
        icon.isHidden = node.isGroup
        if node.isGroup, let subtitle = node.subtitle, !subtitle.isEmpty {
            count.stringValue = subtitle
            count.isHidden = false
        } else {
            count.stringValue = ""
            count.isHidden = true
        }
    }
}
