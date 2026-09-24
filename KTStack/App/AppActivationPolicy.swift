import AppKit
import KTPluginKit

enum AppActivationPolicy {
    static func activateRegular() {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    }

    @MainActor
    @discardableResult
    static func focusDashboard() -> Bool {
        guard let window = KTWindowIdentity.window(sceneID: DashboardWindow.windowID), window.canBecomeMain else {
            return false
        }
        if window.isMiniaturized { window.deminiaturize(nil) }
        window.makeKeyAndOrderFront(nil)
        return true
    }

    @MainActor
    static func resizeDashboard(toFraction fraction: CGFloat) {
        guard let screen = NSScreen.main,
              let window = KTWindowIdentity.window(sceneID: DashboardWindow.windowID)
        else { return }
        let visible = screen.visibleFrame
        let width = (visible.width * fraction).rounded()
        let height = (visible.height * fraction).rounded()
        let origin = NSPoint(
            x: visible.minX + (visible.width - width) / 2,
            y: visible.minY + (visible.height - height) / 2
        )
        window.setFrame(
            NSRect(origin: origin, size: NSSize(width: width, height: height)),
            display: true,
            animate: false
        )
    }

    // A closing window is still in NSApp.windows during windowWillClose, so exclude it; with no
    // ordinary window left, drop back to accessory so the app leaves the Dock for the menu bar.
    static func restoreAccessoryIfNoWindows(excluding closingWindow: NSWindow? = nil) {
        let hasOrdinaryWindow = NSApp.windows.contains { window in
            window !== closingWindow && KTWindowIdentity.keepsAppInDock(
                isVisible: window.isVisible,
                isMiniaturized: window.isMiniaturized,
                canBecomeMain: window.canBecomeMain,
                isPanel: window is NSPanel
            )
        }
        if !hasOrdinaryWindow {
            NSApp.setActivationPolicy(.accessory)
        }
    }
}

@MainActor
final class DashboardOpener {
    static let shared = DashboardOpener()

    var action: (() -> Void)?

    func open() {
        if let action {
            action()
        } else {
            openFromWindowMenu()
        }
    }

    private func openFromWindowMenu() {
        let items = NSApp.mainMenu?.items.flatMap { $0.submenu?.items ?? [] } ?? []
        guard let item = items.first(where: { $0.title == "KTStack Dashboard" }), let action = item.action else { return }
        NSApp.sendAction(action, to: item.target, from: item)
    }
}
