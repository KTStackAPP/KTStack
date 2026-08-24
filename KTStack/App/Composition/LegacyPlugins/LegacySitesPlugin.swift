import KTPluginKit
import KTStackKit
import SwiftUI

final class LegacySitesPlugin: KTStackPlugin {
    let descriptor = PluginDescriptor(id: "sites", title: "Sites", systemImage: "globe")
    private let nav: DashboardNavigation

    init(nav: DashboardNavigation) { self.nav = nav }

    @MainActor func makeContentView() -> AnyView {
        AnyView(KTSitesScreen(
            onOpenLogs: { [nav] in nav.openLogs($0) },
            onNavigate: { [nav] in nav.selection = $0.rawValue }
        ))
    }
}
