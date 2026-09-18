import AppKit
import SwiftUI

struct PluginToolbarItems {
    let leading: AnyView?
    let center: AnyView?
    let trailing: AnyView?

    init(leading: AnyView? = nil, center: AnyView? = nil, trailing: AnyView? = nil) {
        self.leading = leading
        self.center = center
        self.trailing = trailing
    }
}

struct PluginTabContent {
    let content: AnyView
    let viewController: NSViewController?
    let toolbar: AnyView?
    let toolbarItems: PluginToolbarItems?
    let identity: AnyObject?
    let shouldClose: () -> Bool
    let onClose: () -> Void

    init(
        content: AnyView = AnyView(EmptyView()),
        viewController: NSViewController? = nil,
        toolbar: AnyView? = nil,
        toolbarItems: PluginToolbarItems? = nil,
        identity: AnyObject? = nil,
        shouldClose: @escaping () -> Bool = { true },
        onClose: @escaping () -> Void = {}
    ) {
        self.content = content
        self.viewController = viewController
        self.toolbar = toolbar
        self.toolbarItems = toolbarItems
        self.identity = identity
        self.shouldClose = shouldClose
        self.onClose = onClose
    }
}
