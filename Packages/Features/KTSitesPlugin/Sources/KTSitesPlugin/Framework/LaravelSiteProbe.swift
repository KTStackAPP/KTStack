import Foundation

struct LaravelSiteProbe: Sendable {
    func isLaravel(siteAt folder: URL, fileManager: FileManager = .default) -> Bool {
        fileManager.fileExists(atPath: folder.appendingPathComponent("artisan").path)
    }
}
