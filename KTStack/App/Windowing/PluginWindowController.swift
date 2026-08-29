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

// Cửa sổ workspace: ⌘T (newWindowForTab) đi lên responder chain tới đây rồi gọi closure.
final class TabbingWindow: NSWindow {
    var onNewTab: (() -> Void)?
    override func newWindowForTab(_: Any?) { onNewTab?() }
}

@MainActor
final class PluginWindowController: NSObject, NSWindowDelegate {
    private let title: String
    private let autosaveName: String
    private let minSize: NSSize
    private let defaultSize: NSSize
    private let chrome: WindowChrome

    private var window: NSWindow?
    private var tabWindows: [NSWindow] = []
    private var lastContent: AnyView?
    private var onClose: (() -> Void)?
    private var shouldClose: (() -> Bool)?

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

    func present(_ content: AnyView, onClose: @escaping () -> Void, shouldClose: (() -> Bool)? = nil) {
        AppActivationPolicy.activateRegular()
        self.onClose = onClose
        self.shouldClose = shouldClose
        lastContent = content

        if let window {
            window.makeKeyAndOrderFront(nil)
            return
        }

        let window = makeWindow(content: content, primary: true)
        self.window = window
        window.makeKeyAndOrderFront(nil)
    }

    func close() {
        window?.close()
    }

    private func makeWindow(content: AnyView, primary: Bool) -> NSWindow {
        var styleMask: NSWindow.StyleMask = [.titled, .closable, .miniaturizable, .resizable]
        if chrome.fullSizeContentView { styleMask.insert(.fullSizeContentView) }

        let hosting = NSHostingController(rootView: content)
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
            // .unified cần một NSToolbar để titlebar cao đúng; phase 4 thay bằng toolbar thật.
            let toolbar = NSToolbar(identifier: chrome.tabbingIdentifier ?? autosaveName)
            window.toolbar = toolbar
            window.toolbarStyle = style
        }

        if let tabbing = window as? TabbingWindow {
            tabbing.onNewTab = { [weak self] in self?.openTab() }
        }

        if primary {
            window.delegate = self
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

    // Phase 1: tab mới dùng lại content (có thể trùng); phase 3 tách per-tab store.
    private func openTab() {
        guard let content = lastContent, let anchor = window else { return }
        let tab = makeWindow(content: content, primary: false)
        tab.delegate = self
        tabWindows.append(tab)
        anchor.addTabbedWindow(tab, ordered: .above)
        tab.makeKeyAndOrderFront(nil)
    }

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        guard sender == window else { return true }
        return shouldClose?() ?? true
    }

    func windowWillClose(_ notification: Notification) {
        guard let closed = notification.object as? NSWindow else { return }
        if closed != window {
            tabWindows.removeAll { $0 == closed }
            return
        }
        window = nil
        shouldClose = nil
        lastContent = nil
        tabWindows.forEach { $0.close() }
        tabWindows.removeAll()
        let callback = onClose
        onClose = nil
        callback?()
    }
}
