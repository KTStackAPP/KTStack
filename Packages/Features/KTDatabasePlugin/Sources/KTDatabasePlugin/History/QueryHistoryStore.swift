import Foundation
import KTStackCore

public final class QueryHistoryStore {
    static let writeQueue = DispatchQueue(label: "com.ktstack.query-history", qos: .utility)

    public let limit: Int

    private let fileURL: URL
    private let fileManager: FileManager
    private var cache: [QueryHistoryEntry]

    public init(
        paths: AppSupportPaths = AppSupportPaths(),
        limit: Int = 1000,
        fileManager: FileManager = .default
    ) {
        fileURL = paths.queryHistoryFile
        self.limit = limit
        self.fileManager = fileManager
        cache = []
        cache = Self.load(from: fileURL, fileManager: fileManager)
    }

    public func entries() -> [QueryHistoryEntry] {
        cache
    }

    public func record(sql: String, connectionLabel: String, database: String?, ranAt: Date = Date()) throws {
        let trimmed = QueryHistoryRedactor.redact(sql.trimmingCharacters(in: .whitespacesAndNewlines))
        guard !trimmed.isEmpty, trimmed.utf8.count <= QueryHistoryRedactor.maxStoredLength else { return }
        if let first = cache.first,
           first.sql == trimmed,
           first.connectionLabel == connectionLabel,
           first.database == database
        {
            return
        }
        cache.insert(
            QueryHistoryEntry(
                sql: trimmed,
                ranAt: ranAt,
                connectionLabel: connectionLabel,
                database: database
            ),
            at: 0
        )
        if cache.count > limit {
            cache.removeLast(cache.count - limit)
        }
        flush()
    }

    public func clear() throws {
        cache = []
        flush()
    }

    private func flush() {
        let snapshot = cache, url = fileURL
        Self.writeQueue.async {
            do {
                try Self.write(snapshot, to: url)
            } catch {
                NSLog("KTStack: could not save query history: \(error.localizedDescription)")
            }
        }
    }

    static func write(_ entries: [QueryHistoryEntry], to url: URL) throws {
        let fm = FileManager.default
        try fm.createDirectory(
            at: url.deletingLastPathComponent(), withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700]
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(entries).write(to: url, options: .atomic)
        try fm.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
    }

    static func waitForPendingWrites() {
        writeQueue.sync {}
    }

    private static func load(from url: URL, fileManager: FileManager) -> [QueryHistoryEntry] {
        waitForPendingWrites()
        guard fileManager.fileExists(atPath: url.path),
              let data = try? Data(contentsOf: url),
              let entries = try? JSONDecoder().decode([QueryHistoryEntry].self, from: data)
        else {
            return []
        }
        return entries
    }
}
