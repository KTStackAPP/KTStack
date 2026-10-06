import KTPlatformContracts
import KTPluginKit
import SwiftUI

extension SiteInspector {
    func advancedCard(_ site: SiteSummary, settings: SiteSettingsModel) -> some View {
        InspectorCard(title: "Advanced") {
            if settings.showsEnv {
                InspectorRow("Environment") {
                    InspectorValue(SiteDetailSummary.environment(site.envVars))
                } trailing: {
                    InspectorButton(title: "Edit…") { sheet = .environment }
                }
            }
            InspectorRow("Nginx directives") {
                InspectorValue(SiteDetailSummary.directives(site.frontDirectives), muted: site.frontDirectives?.isEmpty ?? true)
            } trailing: {
                InspectorButton(title: "Edit…") { sheet = .directives }
            }
            InspectorRow("Logs") {
                InspectorHint(site.kind == .php ? "nginx, php-fpm for this site" : "nginx for this site")
            } trailing: {
                InspectorButton(title: "Open Logs") { actions.openLogs(site) }
            }
        }
    }

    @ViewBuilder
    func sheetContent(_ sheet: Sheet, site: SiteSummary, settings: SiteSettingsModel) -> some View {
        switch sheet {
        case .environment:
            EnvironmentSheet(site: site, model: settings)
        case .directives:
            DirectivesSheet(site: site, model: settings)
        case .workers:
            DetailSheet(title: "Workers", subtitle: site.domain) {
                SiteWorkersSection(siteID: site.id, vm: vm)
            } buttons: { dismiss in
                KTButton(title: "Done", kind: .primary, action: dismiss)
            }
            .frame(width: 640)
        }
    }
}
