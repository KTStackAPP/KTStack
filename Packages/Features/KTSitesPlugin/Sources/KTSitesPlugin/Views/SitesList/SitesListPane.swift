import KTPlatformContracts
import KTPluginKit
import SwiftUI

struct SitesListPane: View {
    @ObservedObject var vm: SitesViewModel
    @ObservedObject var pane: SitesPaneModel
    let sitesRoot: URL

    @FocusState private var searchFocused: Bool
    @State private var lastVisible: [UUID] = []

    var body: some View {
        let sites = SitesFilter.visible(vm.sites, kind: pane.kindFilter, query: pane.searchText)
        let visibleIDs = sites.map(\.id)
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 10) {
                TextField("Search sites", text: $pane.searchText)
                    .textFieldStyle(.roundedBorder)
                    .focused($searchFocused)
                SitesKindChips(
                    selection: $pane.kindFilter,
                    counts: SitesFilter.counts(vm.sites, query: pane.searchText)
                )
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)

            content(sites)

            SitesDNSFooter(dns: vm.dns, tld: vm.tld, onEnable: vm.enableDNS, onDisable: vm.disableDNS, onReset: vm.resetDNS)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(KTColor.contentBg)
        .background(shortcuts)
        .onChange(of: pane.searchFocusToken) { _ in searchFocused = true }
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
                        workers: vm.workersSummary(for: site)
                    )
                    .equatable()
                    .tag(site.id)
                }
            }
            .listStyle(.plain)
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
            Button("") { pane.focusSearch() }
                .keyboardShortcut("f", modifiers: .command)
                .disabled(!pane.isActive)
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
