import Foundation

public extension SiteRegistry {
    func folderRemovalTarget(_ site: Site, policy: SiteFolderDeletionPolicy = .standard()) throws -> URL? {
        let folder = URL(fileURLWithPath: site.path, isDirectory: true).standardizedFileURL
        let others = sites.filter { $0.id != site.id && $0.hasFolder }.map(\.path)
        if let blocked = policy.deletionBlocker(for: folder, otherSitePaths: others) {
            throw RegistryError.unsafeDeletePath(blocked)
        }
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: folder.path, isDirectory: &isDirectory) else { return nil }
        guard isDirectory.boolValue else { throw RegistryError.notADirectory(folder.path) }
        return folder
    }

    nonisolated static func moveFolderToTrash(_ folder: URL) async throws -> URL? {
        var trashed: NSURL?
        try FileManager.default.trashItem(at: folder, resultingItemURL: &trashed)
        return trashed as URL?
    }
}
