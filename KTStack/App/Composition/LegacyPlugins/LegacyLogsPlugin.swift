import KTPluginKit
import KTStackKit
import SwiftUI

final class LegacyLogsPlugin: KTStackPlugin {
    let descriptor = PluginDescriptor(id: "logs", title: "Logs", systemImage: "text.alignleft")
    private let nav: DashboardNavigation

    init(nav: DashboardNavigation) { self.nav = nav }

    @MainActor func makeContentView() -> AnyView {
        AnyView(LogsSectionView(nav: nav))
    }
}
