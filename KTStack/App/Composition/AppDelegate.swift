import AppKit
import KTDatabasePlugin
import KTDoctorPlugin
import KTDumpsPlugin
import KTLogsPlugin
import KTMailPlugin
import KTPlatformContracts
import KTPluginKit
import KTRuntimesPlugin
import KTServicesPlugin
import KTSitesPlugin
import KTStackCore
import KTStackKit
import KTTunnelPlugin
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

    @MainActor lazy var runtimesPlugin = KTRuntimesPlugin(
        runtimes: runtimes,
        webEngine: server,
        phpSites: server,
        phpConfig: PHPConfigService(
            paths: AppSupportPaths(),
            reloadPool: { [server] in try await server.reloadPHPPool(version: $0) },
            restartPool: { [server] in try await server.restartPHPPool(version: $0) }
        ),
        engines: services
    )

    @MainActor lazy var updater = UpdaterController()

    @MainActor lazy var uninstaller = UninstallService(
        paths: AppSupportPaths(), dns: dns,
        mkcertBinary: Self.bundleBinDir.appendingPathComponent("mkcert")
    )

    @MainActor lazy var caTrust = CATrustService(
        paths: AppSupportPaths(), mkcertBinary: Self.bundleBinDir.appendingPathComponent("mkcert")
    )

    @MainActor lazy var databasePlugin = KTDatabasePlugin(
        tools: DatabaseToolsService(paths: AppSupportPaths()),
        engines: services,
        route: { [weak self] route in self?.routeDatabase(route) }
    )

    @MainActor lazy var databaseWindows = DatabaseWindows(plugin: databasePlugin)

    #if DEBUG
        @MainActor func openSQLDrafts() { databaseWindows.handle(.sqlDrafts) }
    #endif

    @MainActor lazy var tunnelPlugin = KTTunnelPlugin(
        origin: TunnelOriginService(
            paths: AppSupportPaths(),
            resolveSite: { [weak self] id in self?.server.registry.sites.first { $0.id == id } }
        ),
        jobs: TunnelJobRunner(paths: AppSupportPaths()),
        binaries: CloudflaredBinaryProvisioner(paths: AppSupportPaths())
    )

    @MainActor lazy var modals = KTModalPresenter()

    @MainActor lazy var siteProvisioning = SiteProvisioningService(paths: AppSupportPaths(), server: server)

    @MainActor lazy var sitesPlugin = KTSitesPlugin(
        catalog: server,
        server: server,
        webEngine: server,
        provisioning: siteProvisioning,
        restore: siteProvisioning,
        ide: siteProvisioning,
        routes: RouteIntrospectionService(paths: AppSupportPaths()),
        dns: dns,
        runtimes: runtimes,
        sharing: tunnelPlugin.manager,
        modals: modals,
        sitesRoot: { [preferences] in preferences.sitesRootURL },
        httpsByDefault: { [preferences] in preferences.serveHTTPSByDefault },
        route: { [weak self] in self?.routeSites($0) }
    )

    // 8 plugin id + settings/about (shell rows): frozen, dùng validate selection đã lưu.
    static let frozenSelectionIDs: Set<String> = [
        "sites", "services", "runtimes", "database",
        "logs", "mail", "dumps", "doctor",
        "settings", "about",
    ]

    @MainActor lazy var navigation = DashboardNavigation(validIDs: Self.frozenSelectionIDs)

    @MainActor lazy var servicesPlugin = KTServicesPlugin(
        services: services, engines: services, dns: dns, caTrust: caTrust,
        nginxInclude: NginxIncludeService(
            paths: AppSupportPaths(),
            validate: { [server] in await server.validateNginxConfig() },
            reload: { [server] in try await server.reloadNginxConfig() }
        ),
        route: { [weak self] in self?.routeServices($0) }
    )

    @MainActor lazy var logsPlugin = KTLogsPlugin(context: server)

    @MainActor lazy var doctorPlugin = KTDoctorPlugin(
        probes: DoctorProbeService(paths: AppSupportPaths()),
        tld: { [preferences] in preferences.tld },
        registry: { [weak self] in self?.plugins ?? [] },
        route: { [weak self] in self?.routeDoctor($0) }
    )

    @MainActor lazy var pluginSections: [PluginSection] = [
        PluginSection(title: "Manage", plugins: [
            sitesPlugin,
            servicesPlugin,
            runtimesPlugin,
            databasePlugin,
        ]),
        PluginSection(title: "Inspect", plugins: [
            logsPlugin,
            KTMailPlugin(mailpit: services),
            KTDumpsPlugin(php: server),
            doctorPlugin,
        ]),
    ]

    @MainActor var plugins: [any KTStackPlugin] { pluginSections.flatMap(\.plugins) }

    @MainActor lazy var pluginLifecycle = PluginLifecycleCoordinator(
        plugins: plugins,
        standalone: [tunnelPlugin]
    )

    @MainActor lazy var platformLifecycle = PlatformLifecycle(server: server)

    @MainActor lazy var dashboardEnv = DashboardEnv(
        preferences: preferences,
        server: server,
        dns: dns,
        services: services,
        runtimes: runtimes,
        caTrust: caTrust,
        updater: updater,
        uninstaller: uninstaller,
        modals: modals
    )

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
        tunnelPlugin.reapStaleJobs()
        server.onSitesChanged = { [tunnelPlugin] sites in
            tunnelPlugin.manager.reconcile(targets: sites.map {
                TunnelSiteTarget(id: $0.id, domain: $0.domain, secure: $0.secure)
            })
        }
        navigation.openLogsHandler = { [weak self] in self?.logsPlugin.show(sourceID: $0) }
        applyStartupPreferences()
        pluginLifecycle.startAll()
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
        // Plugin dọn resource của mình trước, platform teardown sau (chi tiết ở CLAUDE.md ## Invariants).
        MainActor.assumeIsolated { pluginLifecycle }.shutdownAllBlocking()
        MainActor.assumeIsolated { platformLifecycle }.shutdownBlocking()
    }

    @objc
    private func windowWillClose(_ note: Notification) {
        let closingWindow = note.object as? NSWindow
        DispatchQueue.main.async {
            AppActivationPolicy.restoreAccessoryIfNoWindows(excluding: closingWindow)
        }
    }
}
