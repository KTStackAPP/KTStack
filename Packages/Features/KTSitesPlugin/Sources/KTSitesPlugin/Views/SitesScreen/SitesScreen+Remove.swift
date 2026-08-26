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
        if let db = site.databaseName {
            return "This permanently deletes \(site.path), drops the MySQL database “\(db)”, and removes the site from KTStack. This cannot be undone."
        }
        return "This permanently deletes \(site.path) and removes the site from KTStack. This cannot be undone."
    }

    private func remove(_ site: SiteSummary) {
        guard removingSiteID == nil else { return }
        removingSiteID = site.id
        actionError = nil
        Task {
            do {
                try await vm.remove(site, deleteFolder: true, dropDatabase: site.databaseName != nil)
                feedback.toast("Removed \(site.domain)")
            } catch {
                actionError = "Couldn't remove \(site.domain): \(error.localizedDescription)"
            }
            removingSiteID = nil
        }
    }
}
