import AppKit
import KTPlatformContracts
import KTPluginKit
import SwiftUI

struct SitesScreen: View {
    @ObservedObject var vm: SitesViewModel
    @ObservedObject var pane: SitesPaneModel
    let provisioning: any SiteProvisioning
    let restore: any WordPressRestoring
    let ide: any SiteIDEConfiguring
    let modals: KTModalPresenter
    let sitesRoot: URL
    let httpsByDefault: Bool

    @EnvironmentObject var feedback: KTFeedbackCenter

    @State var showScan = false
    @State var restoreSite: SiteSummary?
    @State var removingSiteID: UUID?
    @State var removeSite: SiteSummary?
    @State var actionError: String?

    var body: some View {
        VStack(spacing: 0) {
            SitesHeader(
                siteCount: vm.sites.count,
                isRunning: vm.server.isRunning,
                isBusy: vm.server.isBusy,
                onToggleServer: vm.toggleServer,
                onScan: { showScan = true },
                onNewSite: openNewSite
            )
                .padding(.horizontal, KTSpacing.screenGutter)
                .padding(.top, 18)

            if !vm.server.isRunning, !vm.sites.isEmpty {
                stoppedBanner
                    .padding(.horizontal, KTSpacing.screenGutter)
                    .padding(.top, 14)
            }

            if let actionError = vm.server.lastError ?? actionError {
                Text(actionError)
                    .font(.jbMono(12))
                    .foregroundStyle(KTColor.danger)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, KTSpacing.screenGutter)
                    .padding(.top, 6)
            }

            SitesSplitRepresentable(
                pane: pane,
                list: AnyView(
                    SitesListPane(vm: vm, pane: pane, sitesRoot: sitesRoot)
                        .environmentObject(feedback)
                        .ktTooltipHost()
                ),
                inspector: AnyView(
                    SiteInspector(vm: vm, pane: pane, actions: inspectorActions)
                        .environmentObject(feedback)
                        .ktTooltipHost()
                )
            )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.top, 14)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(shortcuts)
        .ktTooltipHost()
        .ktFeedbackHost(feedback)
        .background(KTColor.contentBg)
        .sheet(isPresented: $showScan) {
            ScanImportSheet(
                provisioning: provisioning,
                sitesRoot: sitesRoot,
                tld: vm.tld,
                existingPaths: vm.sites.map(\.path),
                defaultPHPVersion: vm.defaultPHP
            )
        }
        .sheet(item: $restoreSite) {
            RestoreBackupSheet(site: $0, restoring: restore, availableVersions: vm.server.phpVersions, isEndOfLife: vm.isEndOfLife)
        }
        .sheet(item: $removeSite) { site in
            RemoveSiteSheet(site: site) { remove(site, options: $0) }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            vm.refreshDNS()
            vm.refreshEditors()
        }
        .onReceive(NotificationCenter.default.publisher(for: UserDefaults.didChangeNotification).receive(on: DispatchQueue.main)) { _ in
            vm.syncPreferredEditor()
        }
    }

    private var stoppedBanner: some View {
        HStack(spacing: 12) {
            Text("The web server is stopped. Sites will not open until you start it.")
                .font(.jbMono(12.5))
                .foregroundStyle(KTColor.ink)
            Spacer()
            KTButton(title: "Start Server", kind: .primary) { vm.toggleServer() }
                .disabled(vm.server.isBusy)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(RoundedRectangle(cornerRadius: 10).fill(Color(nsColor: .systemOrange).opacity(0.12)))
    }

    private var inspectorActions: SiteInspectorActions {
        SiteInspectorActions(
            openLogs: vm.openLogs,
            toggleShare: toggleShare,
            recheckType: recheckType,
            configureVSCode: configureVSCode,
            restore: { restoreSite = $0 },
            remove: confirmRemove,
            reportError: { actionError = $0 }
        )
    }

    private var shortcuts: some View {
        ZStack {
            Button("") { pane.inspectorVisible.toggle() }
                .keyboardShortcut("i", modifiers: [.command, .option])
                .disabled(!pane.isActive)
        }
        .opacity(0)
        .frame(width: 0, height: 0)
        .accessibilityHidden(true)
    }

    private func openNewSite() {
        let model = NewSiteModel(provisioning: provisioning, catalog: vm.catalog)
        modals.present(id: "sites.new-site") {
            KTModalCard(
                icon: "plus.app",
                tint: KTIconTint.cube,
                title: "New Site",
                subtitle: "Create a new site or import an existing folder",
                width: 680,
                onClose: modals.dismiss
            ) {
                NewSiteForm(
                    model: model,
                    provisioning: provisioning,
                    availableVersions: vm.server.phpVersions,
                    sitesRoot: sitesRoot,
                    tld: vm.tld,
                    defaultPHPVersion: vm.defaultPHP,
                    defaultHTTPS: httpsByDefault,
                    onClose: modals.dismiss
                )
            }
        }
    }

    func configureVSCode(_ site: SiteSummary) {
        do { try SiteActions.configureVSCode(site, ide: ide) }
        catch { actionError = error.localizedDescription }
    }
}
