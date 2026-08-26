import KTPlatformContracts
import KTPluginKit
import SwiftUI

extension SitesScreen {
    var list: some View {
        LazyVStack(spacing: 0) {
            ForEach(Array(filteredSites.enumerated()), id: \.element.id) { index, site in
                SiteListRow(
                    site: site,
                    availableVersions: vm.server.phpVersions,
                    canOpen: vm.server.isRunning,
                    upstreamRunning: vm.upstreamRunning[site.id] ?? false,
                    share: vm.shares[site.id],
                    framework: vm.frameworks[site.id] ?? .plain,
                    apacheInstalled: vm.webEngine.installed,
                    apacheInstalling: vm.webEngine.installing,
                    onOpen: { SiteActions.openInBrowser(site) },
                    onSetVersion: { vm.setPHP(site.id, $0) },
                    onSetSecure: { vm.setSecure(site.id, $0) },
                    onSetEngine: { vm.setEngine(site.id, $0) },
                    onInstallApache: { vm.installApache() },
                    onEditDomain: { try vm.editDomain(site.id, $0) },
                    onSetNodePort: { try vm.setNodePort(site.id, $0) },
                    onSetProxyTarget: { try vm.setProxyTarget(site.id, $0) },
                    onOpenLogs: { vm.openLogs(site) },
                    onToggleShare: { toggleShare(site, $0) },
                    onRemove: { confirmRemove(site) },
                    onConfigureVSCode: { configureVSCode(site) },
                    onRestore: { restoreSite = site },
                    onError: { actionError = $0 }
                )
                .equatable()
                if index < filteredSites.count - 1 {
                    Rectangle().fill(KTColor.sepFaint).frame(height: 0.5).padding(.leading, 16)
                }
            }
        }
    }

    var grid: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 252), spacing: 14)], spacing: 14) {
            ForEach(filteredSites) { site in
                SiteGridCard(
                    site: site,
                    availableVersions: vm.server.phpVersions,
                    canOpen: vm.server.isRunning,
                    isSharing: vm.shares[site.id] != nil,
                    shareStarting: vm.shares[site.id]?.starting ?? false,
                    shareURL: vm.shares[site.id]?.publicURL,
                    shareExpiresAt: vm.shares[site.id]?.expiresAt,
                    apacheInstalled: vm.webEngine.installed,
                    apacheInstalling: vm.webEngine.installing,
                    framework: vm.frameworks[site.id] ?? .plain,
                    onOpen: { SiteActions.openInBrowser(site) },
                    onSetVersion: { vm.setPHP(site.id, $0) },
                    onSetSecure: { vm.setSecure(site.id, $0) },
                    onSetEngine: { vm.setEngine(site.id, $0) },
                    onInstallApache: { vm.installApache() },
                    onOpenLogs: { vm.openLogs(site) },
                    onToggleShare: { toggleShare(site, $0) },
                    onRemove: { confirmRemove(site) },
                    onConfigureVSCode: { configureVSCode(site) },
                    onRestore: { restoreSite = site }
                )
            }
        }
    }

    func toggleShare(_ site: SiteSummary, _ on: Bool) {
        if on {
            vm.startShare(site)
        } else {
            vm.stopShare(siteID: site.id)
        }
    }
}
