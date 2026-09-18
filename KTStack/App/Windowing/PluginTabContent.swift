import AppKit
import SwiftUI

struct PluginTabContent {
    let content: AnyView
    let viewController: NSViewController?
    let toolbar: AnyView?
    let identity: AnyObject?
    let shouldClose: () -> Bool
    let onClose: () -> Void

    init(
        content: AnyView = AnyView(EmptyView()),
        viewController: NSViewController? = nil,
        toolbar: AnyView? = nil,
        identity: AnyObject? = nil,
        shouldClose: @escaping () -> Bool = { true },
        onClose: @escaping () -> Void = {}
    ) {
        self.content = content
        self.viewController = viewController
        self.toolbar = toolbar
        self.identity = identity
        self.shouldClose = shouldClose
        self.onClose = onClose
    }
}
