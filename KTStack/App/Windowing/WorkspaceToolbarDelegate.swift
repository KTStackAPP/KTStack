import AppKit

final class WorkspaceToolbarDelegate: NSObject, NSToolbarDelegate {
    static let itemID = NSToolbarItem.Identifier("com.ktstack.workspaceToolbar")
    private let view: NSView

    init(view: NSView) {
        self.view = view
    }

    func toolbar(
        _: NSToolbar,
        itemForItemIdentifier identifier: NSToolbarItem.Identifier,
        willBeInsertedIntoToolbar _: Bool
    ) -> NSToolbarItem? {
        guard identifier == Self.itemID else { return nil }
        let item = NSToolbarItem(itemIdentifier: identifier)
        item.view = view
        return item
    }

    func toolbarDefaultItemIdentifiers(_: NSToolbar) -> [NSToolbarItem.Identifier] { [Self.itemID] }
    func toolbarAllowedItemIdentifiers(_: NSToolbar) -> [NSToolbarItem.Identifier] { [Self.itemID] }
}
