import Foundation

// Lưu filter preset theo (database, table) ra JSON, .bak rollback khi decode hỏng.
@MainActor
public final class FilterPresetStore {
    private let storeURL: URL
    private var byTable: [String: [FilterPreset]] = [:]

    public init(storeURL: URL) {
        self.storeURL = storeURL
        load()
    }

    private static func key(database: String, table: String) -> String {
        "\(database)\u{1F}\(table)"
    }

    public func presets(database: String, table: String) -> [FilterPreset] {
        byTable[Self.key(database: database, table: table)] ?? []
    }

    public func save(_ preset: FilterPreset, database: String, table: String) {
        let key = Self.key(database: database, table: table)
        var list = byTable[key] ?? []
        list.removeAll { $0.name == preset.name }
        list.append(preset)
        byTable[key] = list
        persist()
    }

    public func remove(name: String, database: String, table: String) {
        let key = Self.key(database: database, table: table)
        guard var list = byTable[key] else { return }
        list.removeAll { $0.name == name }
        if list.isEmpty { byTable[key] = nil } else { byTable[key] = list }
        persist()
    }

    private func load() {
        guard let data = try? Data(contentsOf: storeURL) else { return }
        if let decoded = try? JSONDecoder().decode([String: [FilterPreset]].self, from: data) {
            byTable = decoded
        } else {
            let backup = storeURL.appendingPathExtension("bak")
            try? FileManager.default.removeItem(at: backup)
            try? FileManager.default.copyItem(at: storeURL, to: backup)
            NSLog("KTStack: could not decode filter presets; backed up to \(backup.lastPathComponent)")
        }
    }

    private func persist() {
        do {
            try FileManager.default.createDirectory(
                at: storeURL.deletingLastPathComponent(),
                withIntermediateDirectories: true,
                attributes: [.posixPermissions: 0o700]
            )
            let data = try JSONEncoder().encode(byTable)
            try data.write(to: storeURL, options: .atomic)
        } catch {
            NSLog("KTStack: failed to persist filter presets: \(error.localizedDescription)")
        }
    }
}
