import Foundation
import KTStackCore

/// Identifies one table's grid layout. Distinct per connection/database/schema/table so a saved
/// layout only ever restores for the exact table it was captured on.
public struct TableIdentity: Equatable, Sendable {
    public let profileID: UUID
    public let database: String
    public let schema: String
    public let table: String

    public init(profileID: UUID, database: String, schema: String, table: String) {
        self.profileID = profileID
        self.database = database
        self.schema = schema
        self.table = table
    }

    public var storageKey: String {
        "\(profileID.uuidString)|\(database)|\(schema)|\(table)"
    }
}

public struct ColumnLayout: Equatable, Sendable, Codable {
    public let name: String
    public var isVisible: Bool
    public var width: Double?

    public init(name: String, isVisible: Bool = true, width: Double? = nil) {
        self.name = name
        self.isVisible = isVisible
        self.width = width
    }
}

private struct TableGridLayout: Codable {
    let key: String
    var columns: [ColumnLayout]
}

/// Persists per-table column visibility, order and width. Order is the array position. Low-stakes UI
/// state, so an atomic JSON write (no `.bak`) mirrors QueryHistoryStore.
public final class GridColumnLayoutStore {
    private let fileURL: URL
    private let fileManager: FileManager
    private var cache: [String: [ColumnLayout]]

    public init(
        fileURL: URL = AppSupportPaths().config.appendingPathComponent("grid-column-layouts.json"),
        fileManager: FileManager = .default
    ) {
        self.fileURL = fileURL
        self.fileManager = fileManager
        cache = Self.load(from: fileURL, fileManager: fileManager)
    }

    public func layout(for identity: TableIdentity) -> [ColumnLayout]? {
        cache[identity.storageKey]
    }

    public func save(_ columns: [ColumnLayout], for identity: TableIdentity) throws {
        cache[identity.storageKey] = columns
        try flush()
    }

    public func remove(for identity: TableIdentity) throws {
        cache.removeValue(forKey: identity.storageKey)
        try flush()
    }

    /// Merges the stored layout with the current column set: keeps stored order/visibility/width for
    /// columns that still exist, drops stale ones, appends new columns visible at the end.
    public func reconciled(for identity: TableIdentity, columns names: [String]) -> [ColumnLayout] {
        let stored = cache[identity.storageKey] ?? []
        let present = Set(names)
        var result = stored.filter { present.contains($0.name) }
        let known = Set(result.map(\.name))
        for name in names where !known.contains(name) {
            result.append(ColumnLayout(name: name))
        }
        return result
    }

    private func flush() throws {
        let parent = fileURL.deletingLastPathComponent()
        try fileManager.createDirectory(at: parent, withIntermediateDirectories: true)
        let records = cache
            .map { TableGridLayout(key: $0.key, columns: $0.value) }
            .sorted { $0.key < $1.key }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(records)
        try data.write(to: fileURL, options: .atomic)
    }

    private static func load(from url: URL, fileManager: FileManager) -> [String: [ColumnLayout]] {
        guard fileManager.fileExists(atPath: url.path),
              let data = try? Data(contentsOf: url),
              let records = try? JSONDecoder().decode([TableGridLayout].self, from: data)
        else {
            return [:]
        }
        return Dictionary(uniqueKeysWithValues: records.map { ($0.key, $0.columns) })
    }
}
