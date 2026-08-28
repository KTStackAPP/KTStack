import Foundation
import KTStackCore

// Lưu câu SQL đặt tên, mới nhất trước; chỉ chứa văn bản, không kèm thông tin kết nối.
public final class QueryFavoriteStore {
    private let fileURL: URL
    private let fileManager: FileManager
    private var cache: [QueryFavorite]

    public init(paths: AppSupportPaths = AppSupportPaths(), fileManager: FileManager = .default) {
        fileURL = paths.queryFavoritesFile
        self.fileManager = fileManager
        cache = Self.load(from: fileURL, fileManager: fileManager)
    }

    public func entries() -> [QueryFavorite] {
        cache
    }

    @discardableResult
    public func add(name: String, sql: String, savedAt: Date = Date()) throws -> QueryFavorite {
        let favorite = QueryFavorite(
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            sql: sql,
            savedAt: savedAt
        )
        cache.insert(favorite, at: 0)
        try flush()
        return favorite
    }

    public func remove(id: UUID) throws {
        cache.removeAll { $0.id == id }
        try flush()
    }

    private func flush() throws {
        let parent = fileURL.deletingLastPathComponent()
        try fileManager.createDirectory(at: parent, withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(cache).write(to: fileURL, options: .atomic)
    }

    private static func load(from url: URL, fileManager: FileManager) -> [QueryFavorite] {
        guard fileManager.fileExists(atPath: url.path),
              let data = try? Data(contentsOf: url),
              let entries = try? JSONDecoder().decode([QueryFavorite].self, from: data)
        else { return [] }
        return entries
    }
}
