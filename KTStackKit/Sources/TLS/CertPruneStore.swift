import Foundation

struct CertPruneStore {
    let certsDir: URL

    var prunedDir: URL {
        certsDir.appendingPathComponent(".pruned", isDirectory: true)
    }

    @discardableResult
    func retire(_ dir: URL) -> URL? {
        let fm = FileManager.default
        try? fm.createDirectory(at: prunedDir, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
        let stamp = Int(Date().timeIntervalSince1970)
        var target = prunedDir.appendingPathComponent("\(dir.lastPathComponent)-\(stamp)", isDirectory: true)
        var suffix = 2
        while fm.fileExists(atPath: target.path) {
            target = prunedDir.appendingPathComponent("\(dir.lastPathComponent)-\(stamp)-\(suffix)", isDirectory: true)
            suffix += 1
        }
        do {
            try fm.moveItem(at: dir, to: target)
            return target
        } catch {
            NSLog("KTStack: could not set aside orphaned cert \(dir.lastPathComponent): \(error.localizedDescription)")
            return nil
        }
    }
}
