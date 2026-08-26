import KTPlatformContracts
import SwiftUI

extension SitesScreen {
    func confirmRemove(_ site: SiteSummary) {
        feedback.confirm(
            title: "Remove \(site.domain)?",
            message: removeMessage(site),
            okLabel: "Remove Site",
            danger: true
        ) { remove(site) }
    }

    private func removeMessage(_ site: SiteSummary) -> String {
        if site.kind == .proxy {
            let target = site.proxyTarget ?? "its upstream"
            return "Removes \(site.domain) from KTStack. The upstream at \(target) is not touched."
        }
        if let db = site.databaseName {
            return "This permanently deletes \(site.path), drops the MySQL database “\(db)”, and removes the site from KTStack. This cannot be undone."
        }
        return "This permanently deletes \(site.path) and removes the site from KTStack. This cannot be undone."
    }

    private func remove(_ site: SiteSummary) {
        guard removingSiteID == nil else { return }
        removingSiteID = site.id
        actionError = nil
        let hasFolder = !site.path.isEmpty
        Task {
            do {
                try await vm.remove(site, deleteFolder: hasFolder, dropDatabase: site.databaseName != nil)
                feedback.toast("Removed \(site.domain)")
            } catch {
                actionError = "Couldn't remove \(site.domain): \(error.localizedDescription)"
            }
            removingSiteID = nil
        }
    }
}
