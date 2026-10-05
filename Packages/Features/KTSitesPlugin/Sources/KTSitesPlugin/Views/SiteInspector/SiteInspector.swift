import KTPlatformContracts
import KTPluginKit
import SwiftUI

struct SiteInspector: View {
    @ObservedObject var vm: SitesViewModel
    @ObservedObject var pane: SitesPaneModel
    let actions: SiteInspectorActions

    var body: some View {
        Group {
            if let site = vm.sites.first(where: { $0.id == pane.selectedID }) {
                content(site)
            } else {
                Text("Select a site")
                    .font(KTType.body)
                    .foregroundStyle(KTColor.muted)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .background(KTColor.contentBg)
    }

    private func content(_ site: SiteSummary) -> some View {
        VStack(spacing: 0) {
            SiteInspectorHeader(
                site: site,
                framework: framework(site),
                canOpen: SiteInspectorInput.canOpen(
                    kind: site.kind,
                    serverRunning: vm.server.isRunning,
                    upstreamRunning: upstreamRunning(site)
                ),
                editors: vm.editors,
                preferredEditor: vm.preferredEditor,
                onOpenLogs: { actions.openLogs(site) },
                onRecheckType: { actions.recheckType(site) },
                onRemove: { actions.remove(site) }
            )
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    domainGroup(site)
                    runtimeGroup(site)
                    securityGroup(site)
                }
                .padding(18)
            }
        }
        .id(site.id)
    }

    func framework(_ site: SiteSummary) -> PHPFramework {
        vm.frameworks[site.id] ?? .plain
    }

    func upstreamRunning(_ site: SiteSummary) -> Bool {
        vm.upstreamRunning[site.id] ?? false
    }
}
