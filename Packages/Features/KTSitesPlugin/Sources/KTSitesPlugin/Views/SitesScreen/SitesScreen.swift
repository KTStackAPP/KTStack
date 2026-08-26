import AppKit
import KTPlatformContracts
import KTPluginKit
import SwiftUI

struct SitesScreen: View {
    @ObservedObject var vm: SitesViewModel
    let provisioning: any SiteProvisioning
    let restore: any WordPressRestoring
    let ide: any SiteIDEConfiguring
    let routes: any APIRouteIntrospecting
    let modals: KTModalPresenter
    let sitesRoot: URL
    let httpsByDefault: Bool

    @EnvironmentObject var feedback: KTFeedbackCenter

    @State var searchText = ""
    @State var gridView = false
    @State var showScan = false
    @State var restoreSite: SiteSummary?
    @State var removingSiteID: UUID?
    @State var actionError: String?

    var filteredSites: [SiteSummary] {
        let q = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
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

            toolbar
                .padding(.horizontal, KTSpacing.screenGutter)
                .padding(.top, 16)

            content
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

            SitesDNSFooter(dns: vm.dns, tld: vm.tld, onEnable: vm.enableDNS, onDisable: vm.disableDNS, onReset: vm.resetDNS)
                .padding(.top, 14)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
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
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            vm.refreshDNS()
        }
    }

    private var serverStatusRow: some View {
        HStack(spacing: 10) {
            HStack(spacing: 8) {
                KTDot(color: vm.server.isRunning ? KTColor.runDot : KTColor.stopDot)
                Text("Server: \(vm.server.isRunning ? "Running" : "Stopped")")
                    .font(.jbMono(13, .medium))
                    .foregroundStyle(vm.server.isRunning ? KTColor.online : KTColor.muted)
            }
            .padding(.vertical, 6)
            .padding(.horizontal, 12)
            .background(Capsule().fill((vm.server.isRunning ? KTColor.runDot : KTColor.stopDot).opacity(0.12)))

            KTButton(title: vm.server.isRunning ? "Stop Server" : "Start Server", kind: .secondary) { vm.toggleServer() }
                .disabled(vm.server.isBusy)
            Spacer()
        }
    }

    private var toolbar: some View {
        HStack(spacing: 10) {
            KTSearchField(text: $searchText, placeholder: "Search sites by name or domain…")
            HStack(spacing: 2) {
                viewToggle(systemImage: "square.grid.2x2", active: gridView) { gridView = true }
                viewToggle(systemImage: "list.bullet", active: !gridView) { gridView = false }
            }
            .padding(3)
            .background(RoundedRectangle(cornerRadius: KTRadius.segment, style: .continuous).fill(KTColor.segmentBg))
        }
    }

    private func viewToggle(systemImage: String, active: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(active ? KTColor.ink : KTColor.ink3)
                .frame(width: 30, height: 26)
                .background(
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(active ? Color.white : Color.clear)
                        .shadow(color: active ? .black.opacity(0.10) : .clear, radius: 1.5, y: 1)
                )
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    var content: some View {
        if vm.sites.isEmpty {
            emptyState(title: "No sites yet", message: "Add a folder under \(sitesRoot.path) to serve it at <name>.\(vm.tld).")
        } else if filteredSites.isEmpty {
            emptyState(title: "No matching sites", message: "No site matches “\(searchText)”.")
        } else if gridView {
            ScrollView { grid.padding(.top, 2).padding(.horizontal, 2).padding(.bottom, 4) }
        } else {
            KTListContainer { ScrollView { list } }
        }
    }

    private func emptyState(title: String, message: String) -> some View {
        VStack(spacing: 6) {
            Image(systemName: "globe").font(.system(size: 46, weight: .light)).foregroundStyle(KTColor.faint)
            Text(title).font(.jbMono(17, .regular)).foregroundStyle(KTColor.ink3)
            Text(message).font(.jbMono(13)).foregroundStyle(KTColor.muted).multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
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

    func openAPITester(_ site: SiteSummary) {
        modals.present(id: "sites.api-tester") {
            APITesterModal(site: site, routes: routes, onClose: modals.dismiss)
        }
    }

    func configureVSCode(_ site: SiteSummary) {
        do { try SiteActions.configureVSCode(site, ide: ide) }
        catch { actionError = error.localizedDescription }
    }
}
