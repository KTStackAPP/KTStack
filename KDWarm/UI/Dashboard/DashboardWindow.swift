import SwiftUI
import KDWarmKit


struct DashboardWindow: View {
    static let windowID = "dashboard"

   
    @EnvironmentObject private var preferences: AppPreferences
    @EnvironmentObject private var dns: DNSAutomationService
    @EnvironmentObject private var server: LocalServerController
    @EnvironmentObject private var caTrust: CATrustService
    @EnvironmentObject private var updater: UpdaterController
    @EnvironmentObject private var uninstaller: UninstallService

    @State private var selection: SidebarItem? = .sites

    @State private var logTarget: String?

    
    private func openLogs(_ sourceID: String?) {
        logTarget = sourceID
        selection = .logs
    }

    var body: some View {
        NavigationSplitView {
            List(SidebarItem.allCases, selection: $selection) { item in
                Label(item.title, systemImage: item.symbol).tag(item)
            }
            .navigationSplitViewColumnWidth(min: 180, ideal: 220, max: 280)
        } detail: {
            detail(for: selection ?? .sites)
        }
        .frame(minWidth: 720, minHeight: 460)
    }

    @ViewBuilder
    private func detail(for item: SidebarItem) -> some View {
        switch item {
        case .sites:    SitesSectionView(onOpenLogs: openLogs)
        case .services: ServicesSectionView(onNavigate: { selection = $0 }, onOpenLogs: openLogs)
        case .runtimes: RuntimesSectionView()
        case .logs:     LogsSectionView(targetSourceID: logTarget)
        case .mail:     MailSectionView()
        case .settings: SettingsView(preferences: preferences, dns: dns, server: server,
                                     caTrust: caTrust, updater: updater, uninstaller: uninstaller)
                            .navigationTitle("Settings")
        case .about:    AboutSettingsView().navigationTitle("About")
        case .database: DatabaseSectionView()
        }
    }
}

enum SidebarItem: String, CaseIterable, Identifiable {
    case sites, services, runtimes, database, logs, mail, settings, about

    var id: String { rawValue }

    var title: String {
        switch self {
        case .sites:    return "Sites"
        case .services: return "Services"
        case .runtimes: return "Runtimes"
        case .database: return "Database"
        case .logs:     return "Logs"
        case .mail:     return "Mail"
        case .settings: return "Settings"
        case .about:    return "About"
        }
    }

    var symbol: String {
        switch self {
        case .sites:    return "globe"
        case .services: return "server.rack"
        case .runtimes: return "cpu"
        case .database: return "cylinder.split.1x2"
        case .logs:     return "text.alignleft"
        case .mail:     return "envelope"
        case .settings: return "gearshape"
        case .about:    return "info.circle"
        }
    }
}
