import Foundation
import KTPlatformContracts

public struct BackupRestoreResult: Equatable, Sendable {
    public var importedDatabases: [String]
    public var failedDatabases: [String]
    public var extractedFolder: URL?
}

public struct BackupRestorer: Sendable {
    let databases: any ScheduledDatabaseBackupProviding
    let paths: BackupPaths
    let outputParent: URL
    let now: @Sendable () -> Date

    public init(databases: any ScheduledDatabaseBackupProviding, paths: BackupPaths, outputParent: URL,
                now: @escaping @Sendable () -> Date = { Date() }) {
        self.databases = databases
        self.paths = paths
        self.outputParent = outputParent
        self.now = now
    }

    public func restore(_ object: RemoteBackupObject, from client: any BackupDestinationClient,
                        progress: @escaping BackupProgressHandler = { _ in }) async throws -> BackupRestoreResult {
        try paths.ensureDirectories()
        let work = paths.restoreStaging.appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: work) }
        try FileManager.default.createDirectory(at: work, withIntermediateDirectories: true)
        let archive = work.appendingPathComponent(object.name)
        try await client.download(object, to: archive, progress: progress)
        if let expected = object.sha256, try FileDigest.sha256Hex(of: archive) != expected.lowercased() {
            throw BackupPipelineError.checksumMismatch
        }
        let extracted = work.appendingPathComponent("extracted", isDirectory: true)
        try ArchiveTool.unzip(archive, into: extracted)
        let content = try Self.contentRoot(in: extracted)
        let manifest = try BackupArchiveManifest.read(in: content)
        guard manifest.formatVersion <= BackupArchiveManifest.currentFormatVersion else {
            throw BackupPipelineError.invalidArchive("it was made by a newer KTStack (format \(manifest.formatVersion)).")
        }
        var result = BackupRestoreResult(importedDatabases: [], failedDatabases: [], extractedFolder: nil)
        for entry in manifest.databases {
            do {
                let directory = try Self.resolve(entry.path, in: content)
                result.importedDatabases += try databases.importStagedBackup(at: directory).map { "\(entry.engine)/\($0)" }
            } catch {
                result.failedDatabases.append("\(entry.engine)/\(entry.database): \(error.localizedDescription)")
            }
        }
        result.extractedFolder = try exportFiles(manifest, from: content)
        return result
    }

    func exportFiles(_ manifest: BackupArchiveManifest, from content: URL) throws -> URL? {
        let relative = manifest.sites.map(\.path) + (manifest.settingsPath.map { [$0] } ?? [])
        guard !relative.isEmpty else { return nil }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd HH.mm.ss"
        let destination = Self.unique(outputParent.appendingPathComponent("KTStack Restore \(formatter.string(from: now()))"))
        let fileManager = FileManager.default
        try fileManager.createDirectory(at: destination, withIntermediateDirectories: true)
        for path in relative {
            let source = try Self.resolve(path, in: content)
            let target = destination.appendingPathComponent(path)
            try fileManager.createDirectory(at: target.deletingLastPathComponent(), withIntermediateDirectories: true)
            try fileManager.moveItem(at: source, to: target)
        }
        try fileManager.copyItem(at: content.appendingPathComponent(BackupArchiveManifest.fileName),
                                 to: destination.appendingPathComponent(BackupArchiveManifest.fileName))
        return destination
    }

    static func contentRoot(in extracted: URL) throws -> URL {
        if FileManager.default.fileExists(atPath: extracted.appendingPathComponent(BackupArchiveManifest.fileName).path) {
            return extracted
        }
        let children = (try? FileManager.default.contentsOfDirectory(at: extracted, includingPropertiesForKeys: nil)) ?? []
        guard let root = children.first(where: {
            FileManager.default.fileExists(atPath: $0.appendingPathComponent(BackupArchiveManifest.fileName).path)
        }) else {
            throw BackupPipelineError.invalidArchive("manifest.json is missing.")
        }
        return root
    }

    static func resolve(_ relative: String, in root: URL) throws -> URL {
        let base = root.standardizedFileURL.resolvingSymlinksInPath().path
        let candidate = root.appendingPathComponent(relative).standardizedFileURL.resolvingSymlinksInPath()
        guard !relative.hasPrefix("/"), candidate.path.hasPrefix(base + "/"),
              FileManager.default.fileExists(atPath: candidate.path) else {
            throw BackupPipelineError.invalidArchive("\(relative) is missing or outside the archive.")
        }
        return candidate
    }

    static func unique(_ url: URL) -> URL {
        var candidate = url
        var index = 2
        while FileManager.default.fileExists(atPath: candidate.path) {
            candidate = url.deletingLastPathComponent().appendingPathComponent("\(url.lastPathComponent) \(index)")
            index += 1
        }
        return candidate
    }
}
