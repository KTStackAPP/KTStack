import KTPluginKit
import KTStackKit
import SwiftUI

final class LegacyServicesPlugin: KTStackPlugin {
    let descriptor = PluginDescriptor(id: "services", title: "Services", systemImage: "server.rack")
    private let nav: DashboardNavigation

    init(nav: DashboardNavigation) { self.nav = nav }

    @MainActor func makeContentView() -> AnyView {
        AnyView(KTServicesScreen(
            onNavigate: { [nav] in nav.selection = $0.rawValue },
            onOpenLogs: { [nav] in nav.openLogs($0) }
        ))
    }
}
