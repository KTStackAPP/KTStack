import Foundation
import KTStackCore

public struct RecentObject: Codable, Equatable, Identifiable, Sendable {
    public let profileID: UUID
    public let database: String
    public let name: String
    public let isView: Bool
    public var openedAt: Date

    public var id: String {
        "\(profileID.uuidString).\(database).\(name)"
    }

    public init(profileID: UUID, database: String, name: String, isView: Bool, openedAt: Date = Date()) {
        self.profileID = profileID
        self.database = database
        self.name = name
        self.isView = isView
        self.openedAt = openedAt
    }
}

public final class RecentObjectStore: @unchecked Sendable {
    public let limit: Int

    private let fileURL: URL
    private let fileManager: FileManager
    private let lock = NSLock()
    private var cache: [RecentObject]

    public init(storeURL: URL, limit: Int = 20, fileManager: FileManager = .default) {
        fileURL = storeURL
        self.limit = limit
        self.fileManager = fileManager
        cache = Self.load(from: storeURL, fileManager: fileManager)
    }

    public convenience init(paths: AppSupportPaths = AppSupportPaths(), limit: Int = 20) {
        let url = paths.config
            .appendingPathComponent("database", isDirectory: true)
            .appendingPathComponent("workspace-recent.json")
        self.init(storeURL: url, limit: limit)
    }

    public func recent() -> [RecentObject] {
        lock.lock(); defer { lock.unlock() }
        return cache
    }

    public func recentDatabases(for profileID: UUID) -> [String] {
        lock.lock(); defer { lock.unlock() }
        var seen = Set<String>()
        var result: [String] = []
        for item in cache where item.profileID == profileID {
            let db = item.database.trimmingCharacters(in: .whitespacesAndNewlines)
            if !db.isEmpty && seen.insert(db).inserted {
                result.append(db)
            }
        }
        return result
    }

    public func record(_ object: RecentObject) {
        lock.lock(); defer { lock.unlock() }
        cache.removeAll { $0.id == object.id }
        cache.insert(object, at: 0)
        if cache.count > limit { cache.removeLast(cache.count - limit) }
        try? flush()
    }

    private func flush() throws {
        try fileManager.createDirectory(
            at: fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true,
            attributes: [.posixPermissions: 0o700]
        )
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(cache)
        try data.write(to: fileURL, options: .atomic)
    }

    private static func load(from url: URL, fileManager: FileManager) -> [RecentObject] {
        guard fileManager.fileExists(atPath: url.path), let data = try? Data(contentsOf: url) else { return [] }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return (try? decoder.decode([RecentObject].self, from: data)) ?? []
    }
}
