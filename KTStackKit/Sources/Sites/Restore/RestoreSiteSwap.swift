import Foundation
import KTStackCore

public struct RestoreSiteSwap: Sendable {
    public struct Record: Sendable, Equatable {
        public let siteFolder: URL
        public let replaced: URL?
        public let discardedNew: URL
    }

    static let replacedSuffix = "-replaced"
    private let paths: AppSupportPaths

    public init(paths: AppSupportPaths) {
        self.paths = paths
    }

    public func swap(prepared: URL, into siteFolder: URL, id: String = UUID().uuidString) throws -> Record {
        let fm = FileManager.default
        try fm.createDirectory(at: paths.restoreStagingRoot, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
        let replaced = paths.restoreStagingRoot.appendingPathComponent(id + Self.replacedSuffix, isDirectory: true)
        let discardedNew = paths.restoreStagingRoot.appendingPathComponent(id + "-rolled-back", isDirectory: true)
        let hadFolder = fm.fileExists(atPath: siteFolder.path)
        if hadFolder { try fm.moveItem(at: siteFolder, to: replaced) }
        do {
            try fm.moveItem(at: prepared, to: siteFolder)
        } catch {
            if hadFolder, !fm.fileExists(atPath: siteFolder.path) { try fm.moveItem(at: replaced, to: siteFolder) }
            throw error
        }
        return Record(siteFolder: siteFolder, replaced: hadFolder ? replaced : nil, discardedNew: discardedNew)
    }

    public func undo(_ record: Record) throws {
        let fm = FileManager.default
        if fm.fileExists(atPath: record.siteFolder.path) {
            try fm.moveItem(at: record.siteFolder, to: record.discardedNew)
        }
        if let replaced = record.replaced {
            try fm.moveItem(at: replaced, to: record.siteFolder)
        }
        try? fm.removeItem(at: record.discardedNew)
    }

    public func commit(_ record: Record) -> String? {
        guard let replaced = record.replaced else { return nil }
        do {
            try FileManager.default.trashItem(at: replaced, resultingItemURL: nil)
            return nil
        } catch {
            return "The previous site files were kept at \(replaced.path) (moving them to the Trash failed)."
        }
    }
}
