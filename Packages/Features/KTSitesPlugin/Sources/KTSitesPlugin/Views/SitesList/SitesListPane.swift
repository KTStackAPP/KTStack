import KTPlatformContracts
import KTPluginKit
import SwiftUI

struct SitesListPane: View {
    @ObservedObject var vm: SitesViewModel
    @ObservedObject var pane: SitesPaneModel
    let sitesRoot: URL

    @State private var lastVisible: [UUID] = []

    var body: some View {
        let sites = SitesFilter.visible(vm.sites, kind: pane.kindFilter, query: pane.searchText)
        let visibleIDs = sites.map(\.id)
        VStack(spacing: 0) {
            content(sites)

            SitesDNSFooter(dns: vm.dns, tld: vm.tld, onEnable: vm.enableDNS, onDisable: vm.disableDNS, onReset: vm.resetDNS)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(KTColor.contentBg)
        .background(shortcuts)
        .onChange(of: visibleIDs) { reconcileSelection($0) }
        .onAppear { reconcileSelection(visibleIDs) }
    }

    @ViewBuilder
    private func content(_ sites: [SiteSummary]) -> some View {
        if vm.sites.isEmpty {
            emptyState(title: "No sites yet", message: "Add a folder under \(sitesRoot.path) to serve it at <name>.\(vm.tld).")
        } else if sites.isEmpty {
            emptyState(title: "No matching sites", message: "Try another name, domain or kind.")
        } else {
            List(selection: $pane.selectedID) {
                ForEach(sites) { site in
                    SiteCompactRow(
                        site: site,
                        upstreamRunning: vm.upstreamRunning[site.id] ?? false,
                        shared: vm.shares[site.id]?.publicURL != nil,
                        workers: vm.workersSummary(for: site),
                        isSelected: pane.selectedID == site.id
                    )
                    .equatable()
                    .background(TableHighlightRemover())
                    .listRowInsets(EdgeInsets(top: 1, leading: 8, bottom: 1, trailing: 8))
                    .listRowSeparator(.hidden)
                    .tag(site.id)
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .safeAreaInset(edge: .top, spacing: 0) { Color.clear.frame(height: 8) }
            .contextMenu(forSelectionType: UUID.self, menu: { _ in EmptyView() }, primaryAction: openFirst)
        }
    }

    private func emptyState(title: String, message: String) -> some View {
        VStack(spacing: 6) {
            Image(systemName: "globe").font(.system(size: 40, weight: .light)).foregroundStyle(KTColor.faint)
            Text(title).font(.jbMono(15)).foregroundStyle(KTColor.ink3)
            Text(message).font(.jbMono(12)).foregroundStyle(KTColor.muted).multilineTextAlignment(.center)
        }
        .padding(.horizontal, 20)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var shortcuts: some View {
        ZStack {
            Button("") { openSelected() }
                .keyboardShortcut("o", modifiers: .command)
                .disabled(!pane.isActive)
        }
        .opacity(0)
        .frame(width: 0, height: 0)
        .accessibilityHidden(true)
    }

    private func reconcileSelection(_ visibleIDs: [UUID]) {
        let next = SitesFilter.reconcile(selected: pane.selectedID, previous: lastVisible, visible: visibleIDs)
        if next != pane.selectedID { pane.selectedID = next }
        lastVisible = visibleIDs
    }

    private func openFirst(_ ids: Set<UUID>) {
        guard vm.server.isRunning, let site = vm.sites.first(where: { ids.contains($0.id) }) else { return }
        SiteActions.openInBrowser(site)
    }

    private func openSelected() {
        guard let id = pane.selectedID else { return }
        openFirst([id])
    }
}
