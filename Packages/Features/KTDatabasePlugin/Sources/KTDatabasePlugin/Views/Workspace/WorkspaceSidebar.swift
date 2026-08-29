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
    let statusFor: (UUID) -> ServerStatus
    var onActivateConnection: (UUID) -> Void
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
        context.coordinator.refreshConnectionStatuses(statusFor)
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

        /// Cập nhật chấm trạng thái trên hàng connection đang hiển thị, không reload cây.
        func refreshConnectionStatuses(_ statusFor: (UUID) -> ServerStatus) {
            guard let outlineView else { return }
            for (id, item) in itemsByID {
                guard case let .connection(profileID) = item.node.kind, id.hasPrefix("conn.") else { continue }
                let row = outlineView.row(forItem: item)
                guard row >= 0,
                      let cell = outlineView.view(atColumn: 0, row: row, makeIfNecessary: false) as? SidebarCellView
                else { continue }
                cell.updateStatus(statusFor(profileID))
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
            guard let node = (item as? SidebarItem)?.node else { return 26 }
            if let subtitle = node.subtitle, !subtitle.isEmpty { return 38 }
            return node.isGroup ? 24 : 26
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
            let status: ServerStatus? = if case let .connection(id) = node.kind { parent.statusFor(id) } else { nil }
            cell.configure(node: node, status: status)
            return cell
        }

        func outlineViewSelectionDidChange(_ notification: Notification) {
            guard !applyingSelection, let outline = notification.object as? NSOutlineView else { return }
            guard outline.selectedRow >= 0,
                  let item = outline.item(atRow: outline.selectedRow) as? SidebarItem else { return }
            switch item.node.kind {
            case let .connection(id): parent.onActivateConnection(id)
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

// Cell: icon + tên (+ dòng phụ host/db) + chấm trạng thái (chỉ hàng connection).
final class SidebarCellView: NSTableCellView {
    private let icon = NSImageView()
    private let label = NSTextField(labelWithString: "")
    private let subLabel = NSTextField(labelWithString: "")
    private let textStack = NSStackView()
    private let dot = NSView()

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
        subLabel.translatesAutoresizingMaskIntoConstraints = false
        subLabel.font = .systemFont(ofSize: 10)
        subLabel.lineBreakMode = .byTruncatingMiddle
        subLabel.textColor = NSColor(KTEditorTheme.label3)
        textStack.translatesAutoresizingMaskIntoConstraints = false
        textStack.orientation = .vertical
        textStack.alignment = .leading
        textStack.spacing = 1
        textStack.setViews([label, subLabel], in: .leading)
        dot.translatesAutoresizingMaskIntoConstraints = false
        dot.wantsLayer = true
        dot.layer?.cornerRadius = 4

        addSubview(icon)
        addSubview(textStack)
        addSubview(dot)
        textField = label
        imageView = icon

        NSLayoutConstraint.activate([
            icon.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 4),
            icon.centerYAnchor.constraint(equalTo: centerYAnchor),
            icon.widthAnchor.constraint(equalToConstant: 16),
            icon.heightAnchor.constraint(equalToConstant: 16),
            textStack.leadingAnchor.constraint(equalTo: icon.trailingAnchor, constant: 6),
            textStack.centerYAnchor.constraint(equalTo: centerYAnchor),
            dot.leadingAnchor.constraint(greaterThanOrEqualTo: textStack.trailingAnchor, constant: 6),
            dot.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8),
            dot.centerYAnchor.constraint(equalTo: centerYAnchor),
            dot.widthAnchor.constraint(equalToConstant: 8),
            dot.heightAnchor.constraint(equalToConstant: 8),
        ])
    }

    func configure(node: SidebarNode, status: ServerStatus?) {
        label.stringValue = node.title
        let weight: NSFont.Weight = node.isGroup ? .semibold : .regular
        let size: CGFloat = node.isGroup ? 11 : 13
        label.font = .systemFont(ofSize: size, weight: weight)
        label.textColor = NSColor(node.isGroup ? KTEditorTheme.label2 : KTEditorTheme.label)
        if let subtitle = node.subtitle, !subtitle.isEmpty {
            subLabel.stringValue = subtitle
            subLabel.isHidden = false
        } else {
            subLabel.stringValue = ""
            subLabel.isHidden = true
        }
        icon.image = NSImage(systemSymbolName: node.systemImage, accessibilityDescription: nil)
        icon.isHidden = node.isGroup
        if let status {
            updateStatus(status)
        } else {
            dot.isHidden = true
        }
    }

    func updateStatus(_ status: ServerStatus) {
        dot.isHidden = false
        dot.layer?.backgroundColor = NSColor(color(for: status)).cgColor
    }

    private func color(for status: ServerStatus) -> Color {
        switch status {
        case .online: KTEditorTheme.Status.running
        case .offline: KTEditorTheme.Status.stopped
        case .connecting: KTEditorTheme.Status.info
        }
    }
}
