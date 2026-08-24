import AppKit
import KTPluginKit
import KTStackCore
import KTStackKit
import ServiceManagement
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    @MainActor lazy var preferences = AppPreferences()

    @MainActor lazy var server: LocalServerController = .init(
        bundleBinDir: Self.bundleBinDir, tld: preferences.tld, adoptRunningStack: true
    )

    @MainActor lazy var dns = DNSAutomationService(
        bundledDnsmasq: Self.bundleBinDir.appendingPathComponent("dnsmasq"),
        tld: preferences.tld
    )

    @MainActor lazy var services: ServiceManager = {
        let manager = ServiceManager(server: server, dns: dns)
        manager.startPolling()
        return manager
    }()

    @MainActor lazy var runtimes = RuntimeManager()

    @MainActor lazy var mail = MailStore()

    @MainActor lazy var updater = UpdaterController()

    @MainActor lazy var uninstaller = UninstallService(
        paths: AppSupportPaths(), dns: dns,
        mkcertBinary: Self.bundleBinDir.appendingPathComponent("mkcert")
    )

    @MainActor lazy var caTrust = CATrustService(
        paths: AppSupportPaths(), mkcertBinary: Self.bundleBinDir.appendingPathComponent("mkcert")
    )

    @MainActor lazy var connectionStore = ConnectionStore(
        storeURL: AppSupportPaths().config
            .appendingPathComponent("database", isDirectory: true)
            .appendingPathComponent("connections.json")
    )

    @MainActor lazy var databaseViewModel = DatabaseViewModel()

    @MainActor lazy var documentViewModel = DocumentViewModel()

    @MainActor lazy var tunnels = TunnelManager()

    // 8 plugin id + settings/about (shell rows): frozen, dùng validate selection đã lưu.
    static let frozenSelectionIDs: Set<String> = [
        "sites", "services", "runtimes", "database",
        "logs", "mail", "dumps", "doctor",
        "settings", "about",
    ]

    @MainActor lazy var navigation = DashboardNavigation(validIDs: Self.frozenSelectionIDs)

    @MainActor lazy var pluginSections: [PluginSection] = [
        PluginSection(title: "Manage", plugins: [
            LegacySitesPlugin(nav: navigation),
            LegacyServicesPlugin(nav: navigation),
            LegacyRuntimesPlugin(nav: navigation),
            LegacyDatabasePlugin(nav: navigation),
        ]),
        PluginSection(title: "Inspect", plugins: [
            LegacyLogsPlugin(nav: navigation),
            LegacyMailPlugin(nav: navigation),
            LegacyDumpsPlugin(nav: navigation),
            LegacyDoctorPlugin(nav: navigation),
        ]),
    ]

    @MainActor var plugins: [any KTStackPlugin] { pluginSections.flatMap(\.plugins) }

    private static func alreadyRunningInstance() -> NSRunningApplication? {
        guard let bundleID = Bundle.main.bundleIdentifier else { return nil }
        let current = NSRunningApplication.current
        return NSRunningApplication.runningApplications(withBundleIdentifier: bundleID)
            .first { $0.processIdentifier != current.processIdentifier }
    }

    private static var bundleBinDir: URL {
        Bundle.main.resourceURL?.appendingPathComponent("bin", isDirectory: true)
            ?? Bundle.main.bundleURL.appendingPathComponent("Contents/Resources/bin", isDirectory: true)
    }

    func applicationDidFinishLaunching(_: Notification) {
        if let existing = Self.alreadyRunningInstance() {
            existing.activate(options: [.activateAllWindows])
            exit(0)
        }

        NSApp.setActivationPolicy(.accessory)
        NSApp.appearance = NSAppearance(named: .aqua)
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(windowWillClose(_:)),
            name: NSWindow.willCloseNotification,
            object: nil
        )
        registerHelperIfSigned()

        _ = services
        refreshShellShim()
        // A crash can leave tunnel launchd jobs and tunnel vhosts behind; clear them before serving,
        // or a stale tunnel vhost fails nginx -t and takes the whole front down.
        tunnels.reapStaleJobs()
        server.onSitesChanged = { [tunnels] sites in tunnels.reconcile(sites: sites) }
        applyStartupPreferences()
    }

    @MainActor
    private func applyStartupPreferences() {
        if HelperIdentity.hasSigningIdentity { preferences.launchAtLogin = LoginItemService.isEnabled }
        updater.setAutomaticChecks(preferences.automaticUpdates)
        updater.setChannel(preferences.releaseChannel == .beta ? "beta" : "")
        if preferences.autoStartServer { services.startAll() }
    }

    private func refreshShellShim() {
        let helper = Bundle.main.bundleURL.appendingPathComponent("Contents/MacOS/ktstack-resolve")
        let manager = ShellPathManager(paths: AppSupportPaths(), helperSource: helper)
        do { try manager.refreshStagedShimIfEnabled() }
        catch { NSLog("KTStack: shell shim refresh skipped — \(error.localizedDescription)") }
    }

    private func registerHelperIfSigned() {
        guard HelperIdentity.hasSigningIdentity else {
            NSLog("KTStack: SMAppService helper registration deferred (no signing identity).")
            return
        }
        guard #available(macOS 13.0, *) else { return }
        let service = SMAppService.daemon(plistName: HelperIdentity.daemonPlistName)
        do {
            try service.register()
            // requiresApproval is the expected first-launch state: the user must enable the helper
            // in System Settings before DNS XPC calls can reach it. Log it apart from a real failure.
            if service.status == .requiresApproval {
                NSLog("KTStack: helper registered, awaiting approval in System Settings > Login Items.")
            }
        } catch {
            NSLog("KTStack: helper registration failed: \(error.localizedDescription)")
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_: NSApplication) -> Bool {
        false
    }

    func applicationWillTerminate(_: Notification) {
        // Block quit until the SwiftNIO event loop is fully down: terminating with it still running
        // crashes on exit. Tear down the DB loop first, then tunnels, then the local server.
        let dbShutdown = DispatchSemaphore(value: 0)
        Task.detached {
            try? await EventLoopProvider.shared.shutdown()
            dbShutdown.signal()
        }
        dbShutdown.wait()

        MainActor.assumeIsolated {
            tunnels.shutdownAll()
            server.shutdownForQuit()
        }
    }

    @objc
    private func windowWillClose(_ note: Notification) {
        let closingWindow = note.object as? NSWindow
        DispatchQueue.main.async {
            AppActivationPolicy.restoreAccessoryIfNoWindows(excluding: closingWindow)
        }
    }
}
