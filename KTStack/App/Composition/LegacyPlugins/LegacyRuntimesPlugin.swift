import KTPluginKit
import KTStackKit
import SwiftUI

final class LegacyRuntimesPlugin: KTStackPlugin {
    let descriptor = PluginDescriptor(id: "runtimes", title: "Runtimes", systemImage: "cube")
    private let nav: DashboardNavigation

    init(nav: DashboardNavigation) { self.nav = nav }

    @MainActor func makeContentView() -> AnyView {
        AnyView(KTRuntimesScreen())
    }
}
