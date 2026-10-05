import Foundation
import KTPlatformContracts

struct BackupStagingBuilder: Sendable {
    let databases: any ScheduledDatabaseBackupProviding
    let settings: SettingsSnapshotWriter

    func stageDatabases(_ selections: [BackupDatabaseSelection], running: Set<DatabaseEngine>, into content: URL,
                        manifest: inout BackupArchiveManifest) async -> [BackupRunItem] {
        var items: [BackupRunItem] = []
        var known: [DatabaseEngine: [String]] = [:]
        for selection in selections {
            let label = "\(selection.engine)/\(selection.database)"
            guard let engine = DatabaseEngine(rawValue: selection.engine) else {
                items.append(BackupRunItem(kind: .database, name: label, succeeded: false, message: "Unknown engine."))
                continue
            }
            guard running.contains(engine) else {
                items.append(failure(label, "\(engine.displayName) isn't running."))
                continue
            }
            do {
                if known[engine] == nil {
                    known[engine] = try await databases.userDatabases(engine)
                }
                guard known[engine]?.contains(selection.database) == true else {
                    items.append(failure(label, "Database \(selection.database) no longer exists."))
                    continue
                }
                let parent = content.appendingPathComponent("databases/\(engine.rawValue)", isDirectory: true)
                try FileManager.default.createDirectory(at: parent, withIntermediateDirectories: true)
                let setDir = try await databases.stageBackup(engine: engine, databases: [selection.database], into: parent)
                let path = "databases/\(engine.rawValue)/\(setDir.lastPathComponent)"
                manifest.databases.append(.init(engine: engine.rawValue, database: selection.database, path: path))
                items.append(BackupRunItem(kind: .database, name: label, succeeded: true))
            } catch {
                items.append(failure(label, error.localizedDescription))
            }
        }
        return items
    }

    func stageSites(_ sites: [BackupSiteFolder], missing requested: [UUID], excludes: [String], into content: URL,
                    manifest: inout BackupArchiveManifest) -> [BackupRunItem] {
        let found = Set(sites.map(\.id))
        var items = requested.filter { !found.contains($0) }.map {
            BackupRunItem(kind: .site, name: $0.uuidString, succeeded: false, message: "Site no longer exists.")
        }
        guard !sites.isEmpty else { return items }
        let directory = content.appendingPathComponent("sites", isDirectory: true)
        let archiver = SiteArchiver(matcher: ExcludeMatcher(patterns: excludes))
        for site in sites {
            let path = "sites/\(SiteArchiver.archiveName(for: site))"
            do {
                try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
                try archiver.archive(site, to: content.appendingPathComponent(path))
                manifest.sites.append(.init(siteID: site.id, name: site.name, path: path))
                items.append(BackupRunItem(kind: .site, name: site.name, succeeded: true))
            } catch {
                items.append(BackupRunItem(kind: .site, name: site.name, succeeded: false, message: error.localizedDescription))
            }
        }
        return items
    }

    func stageSettings(into content: URL, manifest: inout BackupArchiveManifest) -> BackupRunItem {
        do {
            try settings.write(into: content.appendingPathComponent(SettingsSnapshotWriter.folderName, isDirectory: true))
            manifest.settingsPath = SettingsSnapshotWriter.folderName
            return BackupRunItem(kind: .settings, name: "KTStack settings", succeeded: true)
        } catch {
            return BackupRunItem(kind: .settings, name: "KTStack settings", succeeded: false, message: error.localizedDescription)
        }
    }

    private func failure(_ label: String, _ message: String) -> BackupRunItem {
        BackupRunItem(kind: .database, name: label, succeeded: false, message: message)
    }
}
