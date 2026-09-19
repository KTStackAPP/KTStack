import AppKit

final class WorkspaceToolbarDelegate: NSObject, NSToolbarDelegate {
    static let leadingID = NSToolbarItem.Identifier("com.ktstack.toolbar.leading")
    static let centerID = NSToolbarItem.Identifier("com.ktstack.toolbar.center")
    static let trailingID = NSToolbarItem.Identifier("com.ktstack.toolbar.trailing")

    private let leadingView: NSView?
    private let centerView: NSView?
    private let trailingView: NSView?

    init(leadingView: NSView? = nil, centerView: NSView? = nil, trailingView: NSView? = nil) {
        self.leadingView = leadingView
        self.centerView = centerView
        self.trailingView = trailingView
    }

    func toolbar(
        _: NSToolbar,
        itemForItemIdentifier identifier: NSToolbarItem.Identifier,
        willBeInsertedIntoToolbar _: Bool
    ) -> NSToolbarItem? {
        let item = NSToolbarItem(itemIdentifier: identifier)
        item.isBordered = false
        switch identifier {
        case Self.leadingID:
            item.view = leadingView
            return item
        case Self.centerID:
            item.view = centerView
            return item
        case Self.trailingID:
            item.view = trailingView
            return item
        default:
            return nil
        }
    }

    func toolbarDefaultItemIdentifiers(_: NSToolbar) -> [NSToolbarItem.Identifier] {
        var items: [NSToolbarItem.Identifier] = []
        if leadingView != nil { items.append(Self.leadingID) }
        items.append(.flexibleSpace)
        if centerView != nil { items.append(Self.centerID) }
        items.append(.flexibleSpace)
        if trailingView != nil { items.append(Self.trailingID) }
        return items
    }

    func toolbarAllowedItemIdentifiers(_: NSToolbar) -> [NSToolbarItem.Identifier] {
        [Self.leadingID, .flexibleSpace, Self.centerID, Self.trailingID]
    }
}
