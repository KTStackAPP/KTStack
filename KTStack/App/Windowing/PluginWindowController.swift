import AppKit
import SwiftUI

// Chrome cửa sổ: cửa sổ cũ giữ .aqua + titlebar ẩn, cửa sổ workspace dùng native (theo hệ thống, toolbar unified, window tabs).
struct WindowChrome {
    var appearance: NSAppearance?
    var titleVisibility: NSWindow.TitleVisibility
    var titlebarAppearsTransparent: Bool
    var fullSizeContentView: Bool
    var toolbarStyle: NSWindow.ToolbarStyle?
    var tabbingIdentifier: String?
    var tabbingMode: NSWindow.TabbingMode

    static let legacy = WindowChrome(
        appearance: NSAppearance(named: .aqua),
        titleVisibility: .hidden,
        titlebarAppearsTransparent: true,
        fullSizeContentView: true,
        toolbarStyle: nil,
        tabbingIdentifier: nil,
        tabbingMode: .disallowed
    )

    static func native(tabbingIdentifier: String) -> WindowChrome {
        WindowChrome(
            appearance: nil,
            titleVisibility: .visible,
            titlebarAppearsTransparent: false,
            fullSizeContentView: false,
            toolbarStyle: .unified,
            tabbingIdentifier: tabbingIdentifier,
            tabbingMode: .preferred
        )
    }
}

// Toolbar unified một item full-width chứa NSHostingView của WorkspaceToolbar.
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

// Cửa sổ workspace: ⌘T (newWindowForTab) đi lên responder chain tới đây rồi gọi closure.
final class TabbingWindow: NSWindow {
    var onNewTab: (() -> Void)?
    override func newWindowForTab(_: Any?) { onNewTab?() }
}

// Nội dung + vòng đời một cửa sổ/tab: mỗi tab một identity (session) riêng.
// content là view SwiftUI (Document Browser, SQL Drafts) hoặc controller AppKit dựng sẵn (workspace split).
struct TabContent {
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

@MainActor
final class PluginWindowController: NSObject, NSWindowDelegate {
    private let title: String
    private let autosaveName: String
    private let minSize: NSSize
    private let defaultSize: NSSize
    private let chrome: WindowChrome

    // Anchor cho addTabbedWindow; cửa sổ tab khác giữ trong tabWindows.
    private var window: NSWindow?
    private var tabWindows: [NSWindow] = []
    private var perWindow: [ObjectIdentifier: TabContent] = [:]
    private var makeTabContent: (() -> TabContent)?

    // Toolbar unified full-width: giữ delegate + ràng buộc chiều rộng theo từng cửa sổ để cập nhật khi resize.
    private var toolbarDelegates: [ObjectIdentifier: WorkspaceToolbarDelegate] = [:]
    private var toolbarWidthConstraints: [ObjectIdentifier: NSLayoutConstraint] = [:]

    init(
        title: String,
        autosaveName: String,
        minSize: NSSize,
        defaultSize: NSSize,
        chrome: WindowChrome = .legacy
    ) {
        self.title = title
        self.autosaveName = autosaveName
        self.minSize = minSize
        self.defaultSize = defaultSize
        self.chrome = chrome
    }

    // Cửa sổ đơn (Document Browser, SQL Drafts): không tabbing.
    func present(
        _ content: AnyView,
        toolbar: AnyView? = nil,
        onClose: @escaping () -> Void,
        shouldClose: (() -> Bool)? = nil
    ) {
        present(
            initial: TabContent(
                content: content,
                toolbar: toolbar,
                shouldClose: { shouldClose?() ?? true },
                onClose: onClose
            ),
            makeTab: nil
        )
    }

    // Cửa sổ có window tabs: mỗi tab một TabContent riêng từ factory.
    func present(initial: TabContent, makeTab: (() -> TabContent)?) {
        AppActivationPolicy.activateRegular()
        makeTabContent = makeTab

        if let window {
            window.makeKeyAndOrderFront(nil)
            return
        }

        let window = makeWindow(content: initial, primary: true)
        self.window = window
        window.makeKeyAndOrderFront(nil)
    }

    func close() {
        window?.close()
    }

    // Đóng tab đang key (else anchor); dùng cho route .closeWorkspace.
    func closeKeyWindow() {
        (allWindows.first { $0.isKeyWindow } ?? window)?.performClose(nil)
    }

    var allWindows: [NSWindow] {
        (window.map { [$0] } ?? []) + tabWindows
    }

    func select(_ window: NSWindow) {
        window.makeKeyAndOrderFront(nil)
    }

    // Tìm cửa sổ theo identity của TabContent (ví dụ session nối profile nào).
    func window(where predicate: (TabContent) -> Bool) -> NSWindow? {
        for w in allWindows {
            if let tc = perWindow[ObjectIdentifier(w)], predicate(tc) { return w }
        }
        return nil
    }

    func tabContent(for window: NSWindow) -> TabContent? {
        perWindow[ObjectIdentifier(window)]
    }

    // Thêm một tab cụ thể (DatabaseWindows dựng sẵn cho profile chỉ định).
    func addTab(_ content: TabContent) {
        guard let anchor = window else { return }
        let tab = makeWindow(content: content, primary: false)
        tabWindows.append(tab)
        anchor.addTabbedWindow(tab, ordered: .above)
        tab.makeKeyAndOrderFront(nil)
    }

    private func makeWindow(content tc: TabContent, primary: Bool) -> NSWindow {
        var styleMask: NSWindow.StyleMask = [.titled, .closable, .miniaturizable, .resizable]
        if chrome.fullSizeContentView { styleMask.insert(.fullSizeContentView) }

        let hosting: NSViewController = tc.viewController ?? NSHostingController(rootView: tc.content)
        let window: NSWindow = chrome.tabbingIdentifier != nil
            ? TabbingWindow(contentRect: NSRect(origin: .zero, size: defaultSize), styleMask: styleMask, backing: .buffered, defer: false)
            : NSWindow(contentRect: NSRect(origin: .zero, size: defaultSize), styleMask: styleMask, backing: .buffered, defer: false)

        window.contentViewController = hosting
        window.appearance = chrome.appearance
        window.titlebarAppearsTransparent = chrome.titlebarAppearsTransparent
        window.titleVisibility = chrome.titleVisibility
        window.title = title
        window.isReleasedWhenClosed = false
        window.contentMinSize = minSize
        window.tabbingMode = chrome.tabbingMode
        if let id = chrome.tabbingIdentifier { window.tabbingIdentifier = id }

        if let style = chrome.toolbarStyle {
            installToolbar(on: window, style: style, toolbar: tc.toolbar)
        }

        if let tabbing = window as? TabbingWindow {
            tabbing.onNewTab = { [weak self] in self?.openTab() }
        }

        window.delegate = self
        perWindow[ObjectIdentifier(window)] = tc

        if primary {
            window.setFrameAutosaveName(autosaveName)
            if window.frame.width < minSize.width || window.frame.height < minSize.height {
                window.setContentSize(defaultSize)
                window.center()
            }
        } else {
            window.center()
        }
        return window
    }

    private func installToolbar(on window: NSWindow, style: NSWindow.ToolbarStyle, toolbar content: AnyView?) {
        let toolbar = NSToolbar(identifier: chrome.tabbingIdentifier ?? autosaveName)
        toolbar.displayMode = .iconOnly
        toolbar.allowsUserCustomization = false
        window.toolbarStyle = style

        guard let content else {
            window.toolbar = toolbar
            return
        }

        let hosting = NSHostingView(rootView: content)
        hosting.translatesAutoresizingMaskIntoConstraints = false
        let width = hosting.widthAnchor.constraint(equalToConstant: max(defaultSize.width, 400))
        width.isActive = true
        hosting.heightAnchor.constraint(equalToConstant: 44).isActive = true

        let delegate = WorkspaceToolbarDelegate(view: hosting)
        toolbar.delegate = delegate
        window.toolbar = toolbar

        toolbarDelegates[ObjectIdentifier(window)] = delegate
        toolbarWidthConstraints[ObjectIdentifier(window)] = width
        DispatchQueue.main.async { [weak self] in self?.updateToolbarWidth(for: window) }
    }

    private func updateToolbarWidth(for window: NSWindow) {
        guard let constraint = toolbarWidthConstraints[ObjectIdentifier(window)] else { return }
        constraint.constant = max(400, window.frame.width - 12)
    }

    // ⌘T / ＋ tab bar: tab mới từ factory.
    private func openTab() {
        guard let make = makeTabContent, window != nil else { return }
        addTab(make())
    }

    func windowDidResize(_ notification: Notification) {
        guard let resized = notification.object as? NSWindow else { return }
        updateToolbarWidth(for: resized)
    }

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        perWindow[ObjectIdentifier(sender)]?.shouldClose() ?? true
    }

    func windowWillClose(_ notification: Notification) {
        guard let closed = notification.object as? NSWindow else { return }
        let tc = perWindow.removeValue(forKey: ObjectIdentifier(closed))
        toolbarDelegates[ObjectIdentifier(closed)] = nil
        toolbarWidthConstraints[ObjectIdentifier(closed)] = nil
        tabWindows.removeAll { $0 == closed }

        // Anchor đóng nhưng còn tab: đề cử một tab khác làm anchor mới.
        if closed == window {
            window = tabWindows.first
            tabWindows.removeAll { $0 == window }
            if window == nil { makeTabContent = nil }
        }

        tc?.onClose()
    }
}
