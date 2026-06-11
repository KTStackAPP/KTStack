import SwiftUI
import AppKit
import KDWarmKit

@main
struct KDWarmApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        // Menu-bar entry. `.window` style gives a real SwiftUI canvas so status pills
        // and toggles render per the design (a plain `.menu` cannot host them).
        MenuBarExtra("KDWarm", image: "MenuBarGlyph") {
            MenuBarContentView()
                .environmentObject(appDelegate.server)
        }
        .menuBarExtraStyle(.window)

        // Dashboard window, opened on demand from the menu-bar footer.
        Window("KDWarm Dashboard", id: DashboardWindow.windowID) {
            DashboardWindow()
                .environmentObject(appDelegate.server)
        }
        .defaultSize(width: 920, height: 600)
        .windowResizability(.contentMinSize)

        Settings {
            SettingsView()
        }
    }
}

/// Owns the accessory-app launch posture and restores it as windows close.
final class AppDelegate: NSObject, NSApplicationDelegate {
    /// The live nginx + php-fpm orchestrator, shared with the menu bar and dashboard.
    /// Binaries are staged from the bundle's `Resources/bin` into app-support on first start.
    @MainActor lazy var server: LocalServerController = {
        let binDir = Bundle.main.resourceURL?.appendingPathComponent("bin", isDirectory: true)
            ?? Bundle.main.bundleURL.appendingPathComponent("Contents/Resources/bin", isDirectory: true)
        return LocalServerController(bundleBinDir: binDir)
    }()

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Start as a menu-bar-only accessory: no Dock icon, no default window.
        NSApp.setActivationPolicy(.accessory)
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(windowWillClose(_:)),
            name: NSWindow.willCloseNotification,
            object: nil)
    }

    func applicationWillTerminate(_ notification: Notification) {
        // Dev-shim children run in their own process group, so they would survive the app.
        // Stop them explicitly so quitting leaves no orphaned nginx/php-fpm (Phase 2 criterion;
        // Phase 6 changes this to persistent launchd services).
        MainActor.assumeIsolated { server.shutdownForQuit() }
    }

    @objc private func windowWillClose(_ note: Notification) {
        // Defer until after the window is gone, then drop back to accessory if no
        // ordinary windows remain — excluding the window that is closing now.
        let closingWindow = note.object as? NSWindow
        DispatchQueue.main.async {
            AppActivationPolicy.restoreAccessoryIfNoWindows(excluding: closingWindow)
        }
    }
}
