import KTPluginKit
import KTStackKit
import SwiftUI

final class LegacyDatabasePlugin: KTStackPlugin {
    let descriptor = PluginDescriptor(id: "database", title: "Database", systemImage: "cylinder.split.1x2")
    private let nav: DashboardNavigation

    init(nav: DashboardNavigation) { self.nav = nav }

    @MainActor func makeContentView() -> AnyView {
        AnyView(KTDatabaseScreen(nav: nav))
    }
}
