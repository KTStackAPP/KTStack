import KTPlatformContracts
import KTPluginKit
import SwiftUI

// Giữ một SiteSettingsModel cho mỗi site, dùng chung cho nhóm Domain và Advanced.
struct SiteSettingsHost<Content: View>: View {
    @StateObject private var model: SiteSettingsModel
    private let content: (SiteSettingsModel) -> Content

    init(site: SiteSummary, vm: SitesViewModel, @ViewBuilder content: @escaping (SiteSettingsModel) -> Content) {
        _model = StateObject(wrappedValue: SiteSettingsModel(
            site: site,
            validateAliases: { try vm.validateAliases($0, for: site.id) },
            setAliases: { try vm.setAliases(site.id, $0) },
            setWildcardSubdomains: { try vm.setWildcardSubdomains(site.id, $0) },
            setEnvVars: { try vm.setEnvVars(site.id, $0) },
            saveDirectives: { try await vm.saveFrontDirectives(site.id, $0) }
        ))
        self.content = content
    }

    var body: some View {
        content(model)
    }
}
