import AppKit
import KTPluginKit
import KTStackCore
import KTStackKit
import KTTunnelPlugin
import ServiceManagement
import SwiftUI

private struct MenuBarLaunchLabel: View {
    @Environment(\.openWindow) private var openWindow
    @AppStorage("KTStack.monochromeMenuBarIcon") private var monochromeMenuBarIcon = false
    @State private var didLaunchWindow = false

    var body: some View {
        Group {
            if monochromeMenuBarIcon {
                Image(systemName: "server.rack")
                    .symbolRenderingMode(.monochrome)
            } else {
                Image("MenuBarGlyph")
            }
        }
        .accessibilityLabel("KTStack")
        .onAppear {
            guard !didLaunchWindow else { return }
            didLaunchWindow = true
            AppActivationPolicy.activateRegular()
            if !AppActivationPolicy.focusExistingWindow(titled: "KTStack Dashboard") {
                openWindow(id: DashboardWindow.windowID)
            }
            DispatchQueue.main.async {
                AppActivationPolicy.activateRegular()
                AppActivationPolicy.resizeWindow(titled: "KTStack Dashboard", toFraction: 0.8)
            }
        }
    }
}

@main
struct KTStackApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @AppStorage("KTStack.showInMenuBar") private var showInMenuBar = true

    init() {
        LegacyKDWarmMigration.runIfNeeded()
        UserDefaults.standard.register(defaults: ["NSQuitAlwaysKeepsWindows": false])
    }

    static var defaultWindowSize: CGSize {
        let visible = NSScreen.main?.visibleFrame.size ?? CGSize(width: 1440, height: 900)
        return CGSize(width: (visible.width * 0.8).rounded(), height: (visible.height * 0.8).rounded())
    }

    private var settingsPanes: [AnyView] {
        appDelegate.plugins.compactMap { ($0 as? any SettingsProviding)?.makeSettingsPane() }
    }

    var body: some Scene {
        MenuBarExtra(isInserted: Binding(get: { showInMenuBar }, set: { _ in })) {
            MenuBarContentView(plugins: appDelegate.plugins)
                .environmentObject(appDelegate.server)
                .environmentObject(appDelegate.services)
                .environmentObject(appDelegate.runtimes)
                .environmentObject(appDelegate.updater)
        } label: {
            MenuBarLaunchLabel()
        }
        .menuBarExtraStyle(.window)

        Window("KTStack Dashboard", id: DashboardWindow.windowID) {
            DashboardWindow(nav: appDelegate.navigation, pluginSections: appDelegate.pluginSections)
                .environmentObject(appDelegate.preferences)
                .environmentObject(appDelegate.server)
                .environmentObject(appDelegate.dns)
                .environmentObject(appDelegate.services)
                .environmentObject(appDelegate.runtimes)
                .environmentObject(appDelegate.caTrust)
                .environmentObject(appDelegate.updater)
                .environmentObject(appDelegate.uninstaller)
                .environmentObject(appDelegate.connectionStore)
                .environmentObject(appDelegate.databaseViewModel)
                .environmentObject(appDelegate.documentViewModel)
                .environmentObject(appDelegate.tunnels)
        }
        .defaultSize(width: Self.defaultWindowSize.width, height: Self.defaultWindowSize.height)
        .windowResizability(.contentMinSize)

        Settings {
            SettingsView(
                preferences: appDelegate.preferences,
                dns: appDelegate.dns,
                server: appDelegate.server,
                runtimes: appDelegate.runtimes,
                caTrust: appDelegate.caTrust,
                updater: appDelegate.updater,
                uninstaller: appDelegate.uninstaller,
                pluginPanes: settingsPanes
            )
            .frame(width: 480, height: 560) // the standalone Settings window's fixed size
        }
    }
}
