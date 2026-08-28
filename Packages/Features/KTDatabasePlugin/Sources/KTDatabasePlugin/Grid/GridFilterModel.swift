import Foundation

public struct FilterPreset: Equatable, Sendable, Codable {
    public let name: String
    public let conditions: [FilterCondition]

    public init(name: String, conditions: [FilterCondition]) {
        self.name = name
        self.conditions = conditions
    }
}

/// Ordered filter conditions plus in-memory named presets. Presets stay session-scoped here; disk
/// persistence by table identity lands with the filter UI wiring (needs Cell to become Codable).
public struct GridFilterModel: Equatable, Sendable {
    public private(set) var conditions: [FilterCondition]
    public private(set) var presets: [FilterPreset]

    public init(conditions: [FilterCondition] = [], presets: [FilterPreset] = []) {
        self.conditions = conditions
        self.presets = presets
    }

    public var isEmpty: Bool {
        conditions.isEmpty
    }

    public mutating func add(_ condition: FilterCondition) {
        conditions.append(condition)
    }

    public mutating func update(at index: Int, to condition: FilterCondition) {
        guard conditions.indices.contains(index) else { return }
        conditions[index] = condition
    }

    public mutating func remove(at index: Int) {
        guard conditions.indices.contains(index) else { return }
        conditions.remove(at: index)
    }

    public mutating func clear() {
        conditions.removeAll()
    }

    public mutating func savePreset(name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        presets.removeAll { $0.name == trimmed }
        presets.append(FilterPreset(name: trimmed, conditions: conditions))
    }

    public mutating func applyPreset(_ name: String) {
        guard let preset = presets.first(where: { $0.name == name }) else { return }
        conditions = preset.conditions
    }

    public mutating func removePreset(_ name: String) {
        presets.removeAll { $0.name == name }
    }

    /// Redacted WHERE preview: placeholders only, never a literal value (matches SQLPreview).
    public func previewWhere(dialect: SQLDialect) throws -> String? {
        try dialect.whereClausePreview(conditions)
    }
}
