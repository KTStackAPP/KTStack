import Foundation

public struct BackupPaths: Sendable {
    public let root: URL
    public let appSupportRoot: URL

    public init(appSupportRoot: URL) {
        self.appSupportRoot = appSupportRoot
        root = appSupportRoot.appendingPathComponent("scheduled-backups", isDirectory: true)
    }

    public var plansFile: URL {
        root.appendingPathComponent("plans.json")
    }

    public var destinationsFile: URL {
        root.appendingPathComponent("destinations.json")
    }

    public var runsFile: URL {
        root.appendingPathComponent("runs.json")
    }

    public var staging: URL {
        root.appendingPathComponent("staging", isDirectory: true)
    }

    public var archives: URL {
        root.appendingPathComponent("archives", isDirectory: true)
    }

    public var restoreStaging: URL {
        root.appendingPathComponent("restore", isDirectory: true)
    }

    public var logFile: URL {
        appSupportRoot.appendingPathComponent("logs", isDirectory: true).appendingPathComponent("backups.log")
    }

    public func ensureDirectories(fileManager: FileManager = .default) throws {
        for url in [root, staging, archives, restoreStaging] {
            try fileManager.createDirectory(at: url, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
        }
    }
}
