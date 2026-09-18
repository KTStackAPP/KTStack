import AppKit

extension PluginWindowController {
    func windowDidBecomeKey(_ notification: Notification) {
        guard let window = notification.object as? NSWindow else { return }
        ensureTabBarVisible(for: window)
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

        if closed == window {
            window = tabWindows.first
            tabWindows.removeAll { $0 == window }
            if window == nil { makeTabContent = nil }
        }

        if let remaining = window {
            ensureTabBarVisible(for: remaining)
        }

        tc?.onClose()
    }
}
