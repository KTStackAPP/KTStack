import KTPluginKit
import KTStackKit
import SwiftUI

final class LegacyDoctorPlugin: KTStackPlugin {
    let descriptor = PluginDescriptor(id: "doctor", title: "Doctor", systemImage: "stethoscope")
    private let nav: DashboardNavigation

    init(nav: DashboardNavigation) { self.nav = nav }

    @MainActor func makeContentView() -> AnyView {
        AnyView(KTDoctorScreen(onNavigate: { [nav] in nav.selection = $0.rawValue }))
    }
}
