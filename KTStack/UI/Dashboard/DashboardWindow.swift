import KTPluginKit
import KTStackKit
import KTTunnelPlugin
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
    @EnvironmentObject private var tunnels: TunnelManager

    @ObservedObject var nav: DashboardNavigation
    let pluginSections: [PluginSection]

    @StateObject private var overlay = KTOverlayCenter()
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
            tunnels: tunnels,
            overlay: overlay
        )
    }

    var body: some View {
        DashboardSplitRepresentable(nav: nav, env: dashboardEnv, sections: pluginSections)
            .frame(minWidth: 720, minHeight: 460)
            .environmentObject(overlay)
            .ktOverlayHost(overlay)
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

// Navigation vocabulary nội bộ App: screens gọi onNavigate(.services), adapter map .rawValue → selection id.
// Teo dần và xóa khi plugin sở hữu route enum riêng (M04+).
enum SidebarItem: String, CaseIterable, Identifiable {
    case sites, services, runtimes, database, logs, mail, dumps, doctor, settings, about

    var id: String {
        rawValue
    }

    var title: String {
        switch self {
        case .sites: "Sites"
        case .services: "Services"
        case .runtimes: "Runtimes"
        case .database: "Database"
        case .logs: "Logs"
        case .mail: "Mail"
        case .dumps: "Dumps"
        case .doctor: "Doctor"
        case .settings: "Settings"
        case .about: "About"
        }
    }

    var symbol: String {
        switch self {
        case .sites: "globe"
        case .services: "server.rack"
        case .runtimes: "cube"
        case .database: "cylinder.split.1x2"
        case .logs: "text.alignleft"
        case .mail: "envelope"
        case .dumps: "curlybraces"
        case .doctor: "stethoscope"
        case .settings: "gearshape"
        case .about: "info.circle"
        }
    }
}
