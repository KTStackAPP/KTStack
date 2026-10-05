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

    @State var gridView = false
    @State var showScan = false
    @State var restoreSite: SiteSummary?
    @State var settingsSite: SiteSummary?
    @State var removingSiteID: UUID?
    @State var removeSite: SiteSummary?
    @State var actionError: String?

    var filteredSites: [SiteSummary] {
        let q = pane.searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return vm.sites }
        return vm.sites.filter {
            $0.name.localizedCaseInsensitiveContains(q) || $0.domain.localizedCaseInsensitiveContains(q)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            SitesHeader(siteCount: vm.sites.count, onScan: { showScan = true }, onNewSite: openNewSite)
                .padding(.horizontal, KTSpacing.screenGutter)
                .padding(.top, 18)

            serverStatusRow
                .padding(.horizontal, KTSpacing.screenGutter)
                .padding(.top, 14)

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
                inspector: AnyView(inspectorPlaceholder)
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
        .sheet(item: $settingsSite) {
            SiteSettingsSheet(site: $0, vm: vm)
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

    private var serverStatusRow: some View {
        HStack(spacing: 10) {
            HStack(spacing: 8) {
                KTDot(color: vm.server.isRunning ? KTColor.runDot : KTColor.stopDot)
                Text("Server: \(vm.server.isRunning ? "Running" : "Stopped")")
                    .font(.jbMono(13, .medium))
                    .foregroundStyle(vm.server.isRunning ? KTColor.online : KTColor.ink2)
            }
            .padding(.vertical, 6)
            .padding(.horizontal, 12)
            .background(Capsule().fill((vm.server.isRunning ? KTColor.runDot : KTColor.stopDot).opacity(0.12)))

            KTButton(title: vm.server.isRunning ? "Stop Server" : "Start Server", kind: .secondary) { vm.toggleServer() }
                .disabled(vm.server.isBusy)
            Spacer()
        }
    }

    private var inspectorPlaceholder: some View {
        Text("Select a site")
            .foregroundStyle(KTColor.muted)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(KTColor.contentBg)
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
