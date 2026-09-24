import Foundation
import KTPlatformContracts

struct SiteRemovalOptions: Equatable {
    var moveFolderToTrash = false
    var dropDatabase = false

    static func canTrashFolder(_ site: SiteSummary) -> Bool {
        site.kind != .proxy && !site.path.isEmpty
    }

    static func summary(_ site: SiteSummary, options: SiteRemovalOptions) -> String {
        var parts = ["\(site.domain) is removed from KTStack."]
        if site.kind == .proxy {
            parts.append("The upstream at \(site.proxyTarget ?? "its upstream") is not touched.")
            return parts.joined(separator: " ")
        }
        if options.moveFolderToTrash, canTrashFolder(site) {
            parts.append("\(site.path) moves to the Trash.")
        } else if canTrashFolder(site) {
            parts.append("The folder \(site.path) stays on disk.")
        }
        if let db = site.databaseName {
            parts.append(options.dropDatabase
                ? "The MySQL database “\(db)” is dropped. This cannot be undone."
                : "The MySQL database “\(db)” is kept.")
        }
        return parts.joined(separator: " ")
    }
}
