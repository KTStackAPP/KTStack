import AppKit

enum AppActivationPolicy {
    
    static func activateRegular() {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    }

    static func restoreAccessoryIfNoWindows(excluding closingWindow: NSWindow? = nil) {
        let hasOrdinaryWindow = NSApp.windows.contains { window in
            window !== closingWindow
                && window.isVisible
                && window.canBecomeMain
                && !(window is NSPanel)
        }
        if !hasOrdinaryWindow {
            NSApp.setActivationPolicy(.accessory)
        }
    }
}
