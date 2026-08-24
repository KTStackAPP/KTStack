import KTPluginKit
import KTStackKit
import SwiftUI

final class LegacyMailPlugin: KTStackPlugin {
    let descriptor = PluginDescriptor(id: "mail", title: "Mail", systemImage: "envelope")
    private let nav: DashboardNavigation

    init(nav: DashboardNavigation) { self.nav = nav }

    @MainActor func makeContentView() -> AnyView {
        AnyView(MailSectionView(nav: nav))
    }
}
