import KTPluginKit
import KTStackKit
import SwiftUI

struct DashboardWindow: View {
    static let windowID = "dashboard"

    @EnvironmentObject private var preferences: AppPreferences
    @EnvironmentObject private var dns: DNSAutomationService
    @EnvironmentObject private var server: LocalServerController
    @EnvironmentObject private var services: ServiceManager
    @EnvironmentObject private var runtimes: RuntimeManager
    @EnvironmentObject private var caTrust: CATrustService
    @EnvironmentObject private var updater: UpdaterController
    @EnvironmentObject private var uninstaller: UninstallService
    @EnvironmentObject private var modals: KTModalPresenter

    @ObservedObject var nav: DashboardNavigation
    let pluginSections: [PluginSection]

    @State private var showDNSOnboarding = false

    private var dashboardEnv: DashboardEnv {
        DashboardEnv(
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
    }

    var body: some View {
        DashboardSplitRepresentable(nav: nav, env: dashboardEnv, sections: pluginSections)
            .frame(minWidth: 720, minHeight: 460)
            .ignoresSafeArea(.container, edges: .top)
            .background(KTWindowChrome())
            .sheet(isPresented: $showDNSOnboarding) { HelperApprovalView(dns: dns) }
            // Dashboard mở → poll nhanh + sample metrics; đóng → ServiceManager tự hạ cadence.
            .onAppear { services.beginLiveUpdates() }
            .onDisappear { services.endLiveUpdates() }
            .task {
                // Prompt DNS setup once on first launch; without it the resolver never gets set up
                // because nothing else surfaces the step at boot.
                if !preferences.hasSeenDNSSetup, dns.status == .disabled { showDNSOnboarding = true }
                preferences.hasSeenDNSSetup = true
            }
    }
}
