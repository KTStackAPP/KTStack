import AppKit
import SwiftUI

@MainActor
final class PluginWindowController: NSObject, NSWindowDelegate {
    private let title: String
    private let autosaveName: String
    private let minSize: NSSize
    private let defaultSize: NSSize
    private let chrome: WindowChrome

    var window: NSWindow?
    var tabWindows: [NSWindow] = []
    var perWindow: [ObjectIdentifier: PluginTabContent] = [:]
    var makeTabContent: (() -> PluginTabContent)?

    var toolbarDelegates: [ObjectIdentifier: WorkspaceToolbarDelegate] = [:]
    var toolbarWidthConstraints: [ObjectIdentifier: NSLayoutConstraint] = [:]

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

    func present(
        _ content: AnyView,
        toolbar: AnyView? = nil,
        onClose: @escaping () -> Void,
        shouldClose: (() -> Bool)? = nil
    ) {
        present(
            initial: PluginTabContent(
                content: content,
                toolbar: toolbar,
                shouldClose: { shouldClose?() ?? true },
                onClose: onClose
            ),
            makeTab: nil
        )
    }

    func present(initial: PluginTabContent, makeTab: (() -> PluginTabContent)?) {
        AppActivationPolicy.activateRegular()
        makeTabContent = makeTab

        if let window {
            DispatchQueue.main.async { [weak self, weak window] in
                guard let window else { return }
                window.makeKeyAndOrderFront(nil)
                window.orderFrontRegardless()
                self?.ensureTabBarVisible(for: window)
                NSApp.activate(ignoringOtherApps: true)
            }
            return
        }

        let window = makeWindow(content: initial, primary: true)
        self.window = window
        DispatchQueue.main.async { [weak self, weak window] in
            guard let window else { return }
            window.makeKeyAndOrderFront(nil)
            window.orderFrontRegardless()
            self?.ensureTabBarVisible(for: window)
            NSApp.activate(ignoringOtherApps: true)
        }
    }

    func close() {
        window?.close()
    }

    func closeKeyWindow() {
        (allWindows.first { $0.isKeyWindow } ?? window)?.performClose(nil)
    }

    var allWindows: [NSWindow] {
        (window.map { [$0] } ?? []) + tabWindows
    }

    func select(_ window: NSWindow) {
        AppActivationPolicy.activateRegular()
        DispatchQueue.main.async { [weak self, weak window] in
            guard let window else { return }
            window.makeKeyAndOrderFront(nil)
            window.orderFrontRegardless()
            self?.ensureTabBarVisible(for: window)
            NSApp.activate(ignoringOtherApps: true)
        }
    }

    func window(where predicate: (PluginTabContent) -> Bool) -> NSWindow? {
        for w in allWindows {
            if let tc = perWindow[ObjectIdentifier(w)], predicate(tc) { return w }
        }
        return nil
    }

    func tabContent(for window: NSWindow) -> PluginTabContent? {
        perWindow[ObjectIdentifier(window)]
    }

    func addTab(_ content: PluginTabContent) {
        guard let anchor = window else { return }
        AppActivationPolicy.activateRegular()
        let tab = makeWindow(content: content, primary: false)
        tabWindows.append(tab)
        anchor.addTabbedWindow(tab, ordered: .above)
        DispatchQueue.main.async { [weak self, weak tab] in
            guard let tab else { return }
            tab.makeKeyAndOrderFront(nil)
            tab.orderFrontRegardless()
            self?.ensureTabBarVisible(for: tab)
            NSApp.activate(ignoringOtherApps: true)
        }
    }

    private func makeWindow(content tc: PluginTabContent, primary: Bool) -> NSWindow {
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
            installToolbar(on: window, style: style, tabContent: tc)
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
        ensureTabBarVisible(for: window)
        return window
    }

    private func installToolbar(on window: NSWindow, style: NSWindow.ToolbarStyle, tabContent tc: PluginTabContent) {
        let toolbar = NSToolbar(identifier: UUID().uuidString)
        toolbar.displayMode = .iconOnly
        toolbar.allowsUserCustomization = false
        window.toolbarStyle = style

        let delegate: WorkspaceToolbarDelegate
        if let items = tc.toolbarItems {
            let leading = items.leading.map { NSHostingView(rootView: $0) }
            let center = items.center.map { NSHostingView(rootView: $0) }
            let trailing = items.trailing.map { NSHostingView(rootView: $0) }
            delegate = WorkspaceToolbarDelegate(leadingView: leading, centerView: center, trailingView: trailing)
        } else if let content = tc.toolbar {
            let center = NSHostingView(rootView: content)
            delegate = WorkspaceToolbarDelegate(centerView: center)
        } else {
            window.toolbar = toolbar
            return
        }

        toolbar.delegate = delegate
        window.toolbar = toolbar
        toolbarDelegates[ObjectIdentifier(window)] = delegate
    }

    func updateToolbarWidth(for _: NSWindow) {}

    private func openTab() {
        guard let make = makeTabContent, window != nil else { return }
        addTab(make())
    }

    func ensureTabBarVisible(for window: NSWindow) {
        guard chrome.tabbingIdentifier != nil else { return }
        DispatchQueue.main.async { [weak window] in
            guard let window else { return }
            if let tg = window.tabGroup, !tg.isTabBarVisible {
                window.toggleTabBar(nil)
            }
        }
    }
}
