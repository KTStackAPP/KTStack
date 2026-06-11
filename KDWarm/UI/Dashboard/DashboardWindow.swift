import SwiftUI
import KDWarmKit

/// Dashboard shell: a `NavigationSplitView` whose sidebar is driven by `SidebarItem`
/// and whose detail switches to one of the six section views (design-guidelines §5.6).
struct DashboardWindow: View {
    static let windowID = "dashboard"

    @State private var selection: SidebarItem? = .sites

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
        case .sites:    SitesSectionView()
        case .services: ServicesSectionView(onNavigate: { selection = $0 })
        case .runtimes: RuntimesSectionView()
        case .logs:     LogsSectionView()
        case .mail:     MailSectionView()
        case .settings: SettingsView()
        }
    }
}

/// Top-level dashboard destinations (design-guidelines §5.6).
enum SidebarItem: String, CaseIterable, Identifiable {
    case sites, services, runtimes, logs, mail, settings

    var id: String { rawValue }

    var title: String {
        switch self {
        case .sites:    return "Sites"
        case .services: return "Services"
        case .runtimes: return "Runtimes"
        case .logs:     return "Logs"
        case .mail:     return "Mail"
        case .settings: return "Settings"
        }
    }

    var symbol: String {
        switch self {
        case .sites:    return "globe"
        case .services: return "server.rack"
        case .runtimes: return "cpu"
        case .logs:     return "text.alignleft"
        case .mail:     return "envelope"
        case .settings: return "gearshape"
        }
    }
}
