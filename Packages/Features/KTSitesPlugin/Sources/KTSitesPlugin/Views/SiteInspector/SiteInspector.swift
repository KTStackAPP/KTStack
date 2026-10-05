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
                SiteSettingsHost(site: site, vm: vm) { settings in
                    VStack(alignment: .leading, spacing: 22) {
                        domainGroup(site, settings: settings)
                        runtimeGroup(site)
                        securityGroup(site)
                        SiteAdvancedSection(site: site, model: settings, onOpenLogs: { actions.openLogs(site) })
                    }
                    .padding(18)
                }
                // Model giữ kind lúc tạo, nên dựng lại khi Re-detect đổi loại site.
                .id(site.kind)
            }
            Divider()
            footer(site)
        }
        .id(site.id)
    }

    private func footer(_ site: SiteSummary) -> some View {
        HStack(spacing: 8) {
            if site.kind == .php {
                KTButton(title: "Restore Backup…", kind: .secondary) { actions.restore(site) }
                KTButton(title: "Configure VS Code", kind: .secondary) { actions.configureVSCode(site) }
            }
            Spacer()
            KTButton(title: "Remove Site…", kind: .danger) { actions.remove(site) }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
    }

    func framework(_ site: SiteSummary) -> PHPFramework {
        vm.frameworks[site.id] ?? .plain
    }

    func upstreamRunning(_ site: SiteSummary) -> Bool {
        vm.upstreamRunning[site.id] ?? false
    }
}
