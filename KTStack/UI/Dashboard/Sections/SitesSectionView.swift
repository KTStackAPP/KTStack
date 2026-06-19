import SwiftUI
import KTStackKit


struct SitesSectionView: View {
    
    var onOpenLogs: (String?) -> Void = { _ in }

    @EnvironmentObject private var server: LocalServerController
    @EnvironmentObject private var dns: DNSAutomationService
    @EnvironmentObject private var preferences: AppPreferences
    @EnvironmentObject private var tunnels: TunnelManager

    var body: some View {
        SitesContent(server: server, registry: server.registry, dns: dns,
                     preferences: preferences, tunnels: tunnels, onOpenLogs: onOpenLogs)
    }
}

private struct SitesContent: View {
    @ObservedObject var server: LocalServerController
    @ObservedObject var registry: SiteRegistry
    @ObservedObject var dns: DNSAutomationService
    @ObservedObject var preferences: AppPreferences
    @ObservedObject var tunnels: TunnelManager
    var onOpenLogs: (String?) -> Void
    @State private var showAddSheet = false
    @State private var showScanSheet = false
    @State private var showNewSheet = false
    @State private var showImportSheet = false
    @State private var searchText = ""
    @State private var removeError: String?
    @State private var removingSiteID: UUID?
    @State private var pendingRemoval: Site?

    private var filteredSites: [Site] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return registry.sites }
        return registry.sites.filter {
            $0.domain.localizedCaseInsensitiveContains(query)
                || $0.name.localizedCaseInsensitiveContains(query)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            SitesHeaderView(
                siteCount: registry.sites.count,
                serverStatus: server.nginxStatus,
                isRunning: server.isRunning,
                isBusy: server.isBusy,
                onToggleServer: { server.toggle() },
                onScan: { showScanSheet = true },
                onImport: { showImportSheet = true },
                onAddExisting: { showAddSheet = true },
                onNewSite: { showNewSheet = true })
            Divider()
            if registry.sites.isEmpty {
                EmptyStateView(
                    symbol: "globe",
                    title: "No sites yet",
                    message: "Add a folder under \(preferences.sitesRootPath) to serve it at <name>.\(registry.tld).",
                    actionTitle: "Add Site…"
                ) { showAddSheet = true }
            } else {
                VStack(spacing: KDSpacing.space3) {
                    SitesSearchStrip(text: $searchText)
                    list
                }
                .padding(KDSpacing.space4)
            }
            if let error = server.lastError ?? removeError {
                Label(error, systemImage: "exclamationmark.triangle.fill")
                    .font(KDFont.footnote)
                    .foregroundStyle(Color.KDStatus.warning)
                    .padding(KDSpacing.space2)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            DNSStatusBar(dns: dns)
        }
        .navigationTitle("Sites")
        .sheet(isPresented: $showAddSheet) {
            AddSiteSheet(registry: registry, availableVersions: server.availableVersions,
                         sitesRoot: preferences.sitesRootURL)
        }
        .sheet(isPresented: $showScanSheet) {
            ScanImportSheet(registry: registry, sitesRoot: preferences.sitesRootURL)
        }
        .sheet(isPresented: $showNewSheet) {
            NewSiteSheet(registry: registry, availableVersions: server.availableVersions,
                         sitesRoot: preferences.sitesRootURL, tld: registry.tld)
        }
        .sheet(isPresented: $showImportSheet) {
            MigrateImportSheet(registry: registry, availableVersions: server.availableVersions)
        }
        .alert(item: $pendingRemoval, content: removeAlert)
    }

    @ViewBuilder
    private var list: some View {
        if filteredSites.isEmpty {
            EmptyStateView(
                symbol: "magnifyingglass",
                title: "No matching sites",
                message: "No site matches “\(searchText)”.",
                actionTitle: "Clear Search"
            ) { searchText = "" }
        } else {
            siteScroll
        }
    }

    private var siteScroll: some View {
        SitesListSurface {
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(Array(filteredSites.enumerated()), id: \.element.id) { index, site in
                        SiteRowView(
                            site: site,
                            availableVersions: server.availableVersions,
                            canOpen: server.isRunning,
                            onOpen: { open(site) },
                            onRemove: { pendingRemoval = site },
                            onEditDomain: { try registry.editDomain(site, to: $0) },
                            onSetVersion: { registry.setPHPVersion(site, to: $0) },
                            onSetSecure: { server.setSiteSecure(site, $0) },
                            onOpenLogs: { onOpenLogs("site-\(site.domain)-access") },
                            shareStatus: tunnels.session(site.id)?.status ?? .idle,
                            onToggleShare: { on in
                                if on { tunnels.start(site: site) } else { tunnels.stop(site: site.id) }
                            })
                        if index < filteredSites.count - 1 { Divider() }
                    }
                }
            }
        }
    }

    private func open(_ site: Site) {
        let scheme = site.secure ? "https" : "http"
        guard let url = URL(string: "\(scheme)://\(site.domain)/") else { return }
        NSWorkspace.shared.open(url)
    }

    private func removeAlert(_ site: Site) -> Alert {
        Alert(
            title: Text("Remove \(site.domain)?"),
            message: Text(removeConfirmationMessage(for: site)),
            primaryButton: .destructive(Text("Remove Site")) { remove(site) },
            secondaryButton: .cancel()
        )
    }

    private func removeConfirmationMessage(for site: Site) -> String {
        if let databaseName = site.databaseName {
            return "This permanently deletes \(site.path), drops the MySQL database “\(databaseName)”, and removes the site from KTStack. This cannot be undone."
        }
        return "This permanently deletes \(site.path) and removes the site from KTStack. No managed database is linked to this site. This cannot be undone."
    }

    private func remove(_ site: Site) {
        guard removingSiteID == nil else { return }
        removingSiteID = site.id
        removeError = nil
        Task {
            do {
                let coordinator = SiteRemovalCoordinator(
                    deleteFolder: { site in
                        try await MainActor.run { try registry.deleteFolderForRemoval(site) }
                    },
                    dropDatabase: { databaseName in
                        let paths = AppSupportPaths()
                        let mysql = MySQLController(paths: paths, agents: LaunchAgentManager(paths: paths))
                        let database = DatabaseProvisioner(ensureEngine: { try await mysql.start() })
                        try await database.dropDatabase(databaseName)
                    },
                    removeRecord: { site in
                        await MainActor.run { registry.remove(site) }
                    })
                try await coordinator.remove(site)
            } catch {
                removeError = "Couldn't remove \(site.domain): \(error.localizedDescription)"
            }
            removingSiteID = nil
        }
    }
}
