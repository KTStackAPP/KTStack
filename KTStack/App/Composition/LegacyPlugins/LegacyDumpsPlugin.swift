import KTPluginKit
import KTStackKit
import SwiftUI

final class LegacyDumpsPlugin: KTStackPlugin {
    let descriptor = PluginDescriptor(id: "dumps", title: "Dumps", systemImage: "curlybraces")
    private let nav: DashboardNavigation

    init(nav: DashboardNavigation) { self.nav = nav }

    @MainActor func makeContentView() -> AnyView {
        AnyView(DumpsPanelView())
    }
}
