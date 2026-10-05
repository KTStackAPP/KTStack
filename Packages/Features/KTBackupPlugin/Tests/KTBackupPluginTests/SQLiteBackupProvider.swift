import Foundation
import KTPlatformContracts
@testable import KTBackupPlugin

final class SQLiteBackupProvider: ScheduledDatabaseBackupProviding, @unchecked Sendable {
    let databaseDirectory: URL
    let delay: UInt64
    private let lock = NSLock()
    private(set) var imported: [URL] = []

    init(databaseDirectory: URL, delay: UInt64 = 0) {
        self.databaseDirectory = databaseDirectory
        self.delay = delay
    }

    static func createDatabase(_ name: String, in directory: URL, rows: Int) throws {
        let script = "CREATE TABLE notes(id INTEGER PRIMARY KEY, body TEXT);"
            + (0..<rows).map { "INSERT INTO notes(body) VALUES('row \($0)');" }.joined()
        try ArchiveTool.run("/usr/bin/sqlite3", [directory.appendingPathComponent("\(name).sqlite").path, script])
    }

    func installedEngines() -> [DatabaseEngine] {
        [.mysql]
    }

    func userDatabases(_ engine: DatabaseEngine) async throws -> [String] {
        try FileManager.default.contentsOfDirectory(atPath: databaseDirectory.path)
            .filter { $0.hasSuffix(".sqlite") }
            .map { String($0.dropLast(".sqlite".count)) }
            .sorted()
    }

    func stageBackup(engine: DatabaseEngine, databases: [String], into directory: URL) async throws -> URL {
        if delay > 0 { try await Task.sleep(nanoseconds: delay) }
        let set = directory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: set, withIntermediateDirectories: true)
        for database in databases {
            let source = databaseDirectory.appendingPathComponent("\(database).sqlite")
            let dump = set.appendingPathComponent("\(database).sql")
            try ArchiveTool.run("/usr/bin/sqlite3", [source.path, ".output \(dump.path)", ".dump"])
        }
        let meta = ["engine": engine.rawValue, "databases": databases.joined(separator: ",")]
        try JSONSerialization.data(withJSONObject: meta).write(to: set.appendingPathComponent("meta.json"))
        return set
    }

    func importStagedBackup(at directory: URL) throws -> [String] {
        let data = try Data(contentsOf: directory.appendingPathComponent("meta.json"))
        let meta = try JSONSerialization.jsonObject(with: data) as? [String: String] ?? [:]
        locked(lock) { imported.append(directory) }
        return (meta["databases"] ?? "").split(separator: ",").map(String.init)
    }
}
