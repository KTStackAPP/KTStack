import KTPlatformContracts
import SwiftUI

extension SitesScreen {
    func confirmRemove(_ site: SiteSummary) {
        removeSite = site
    }

    func remove(_ site: SiteSummary, options: SiteRemovalOptions) {
        guard removingSiteID == nil else { return }
        removingSiteID = site.id
        actionError = nil
        let deleteFolder = options.moveFolderToTrash && SiteRemovalOptions.canTrashFolder(site)
        let dropDatabase = options.dropDatabase && site.databaseName != nil
        Task {
            do {
                try await vm.remove(site, deleteFolder: deleteFolder, dropDatabase: dropDatabase)
                feedback.toast(deleteFolder ? "Removed \(site.domain); folder moved to Trash" : "Removed \(site.domain)")
            } catch {
                actionError = "Couldn't remove \(site.domain): \(error.localizedDescription)"
            }
            removingSiteID = nil
        }
    }
}
