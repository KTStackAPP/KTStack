import AppKit
import SwiftUI

@MainActor
final class PluginWindowController: NSObject, NSWindowDelegate {
    private let title: String
    private let autosaveName: String
    private let minSize: NSSize
    private let defaultSize: NSSize

    private var window: NSWindow?
    private var onClose: (() -> Void)?

    init(title: String, autosaveName: String, minSize: NSSize, defaultSize: NSSize) {
        self.title = title
        self.autosaveName = autosaveName
        self.minSize = minSize
        self.defaultSize = defaultSize
    }

    func present(_ content: AnyView, onClose: @escaping () -> Void) {
        AppActivationPolicy.activateRegular()
        self.onClose = onClose

        if let window {
            window.makeKeyAndOrderFront(nil)
            return
        }

        let hosting = NSHostingController(rootView: content)
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: defaultSize.width, height: defaultSize.height),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered, defer: false
        )
        window.contentViewController = hosting
        window.appearance = NSAppearance(named: .aqua)
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.title = title
        window.isReleasedWhenClosed = false
        window.delegate = self
        window.contentMinSize = minSize
        window.setFrameAutosaveName(autosaveName)
        if window.frame.width < minSize.width || window.frame.height < minSize.height {
            window.setContentSize(defaultSize)
            window.center()
        }

        self.window = window
        window.makeKeyAndOrderFront(nil)
    }

    func close() {
        window?.close()
    }

    func windowWillClose(_: Notification) {
        window = nil
        let callback = onClose
        onClose = nil
        callback?()
    }
}
