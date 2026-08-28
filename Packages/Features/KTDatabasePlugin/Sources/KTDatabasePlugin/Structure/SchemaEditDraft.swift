import Foundation

/// The editable state of one existing table. Built from server metadata, mutated by the editor,
/// then diffed into an ordered `[SchemaChange]`. Drops run before adds so a column/index removal
/// can't fail on a dependent still present, and the primary key is dropped before columns and
/// re-added after them.
public struct SchemaEditDraft {
    public let tableName: String
    private let originalColumns: [ColumnDraft]
    private let originalIndexes: [IndexDraft]
    private let originalPrimaryKey: [String]

    public var columns: [ColumnDraft]
    public var primaryKey: [String]
    public var indexes: [IndexDraft]
    public var addedForeignKeys: [ForeignKeyDraft]
    public var droppedForeignKeys: [String]
    public var addedChecks: [CheckConstraintDraft]
    public var droppedChecks: [String]
    public var tableOptions: TableOptionDraft

    public init(
        tableName: String,
        columns: [ColumnInfo],
        indexes: [IndexInfo],
        primaryKey: [String]? = nil
    ) {
        self.tableName = tableName
        let drafts = columns.map { Self.draft(from: $0) }
        originalColumns = drafts
        self.columns = drafts
        let indexDrafts = indexes.map { IndexDraft(name: $0.name, columns: $0.columns, isUnique: $0.isUnique) }
        originalIndexes = indexDrafts
        self.indexes = indexDrafts.filter { $0.name != "PRIMARY" }
        // Thứ tự khóa chính lấy từ index PRIMARY (đúng key order), không phải thứ tự cột.
        let primaryIndex = indexes.first { $0.name == "PRIMARY" }?.columns
        let pk = primaryKey ?? primaryIndex ?? columns.filter(\.isPrimaryKey).map(\.name)
        originalPrimaryKey = pk
        self.primaryKey = pk
        addedForeignKeys = []
        droppedForeignKeys = []
        addedChecks = []
        droppedChecks = []
        tableOptions = TableOptionDraft()
    }

    public func changes() -> [SchemaChange] {
        var result: [SchemaChange] = []
        result.append(contentsOf: droppedForeignKeys.map { .dropForeignKey($0) })
        result.append(contentsOf: droppedIndexChanges())
        result.append(contentsOf: droppedChecks.map { .dropCheck($0) })
        let pkChanged = primaryKey != originalPrimaryKey
        if pkChanged, !originalPrimaryKey.isEmpty {
            result.append(.dropPrimaryKey)
        }
        result.append(contentsOf: droppedColumnChanges())
        result.append(contentsOf: modifiedColumnChanges())
        result.append(contentsOf: addedColumnChanges())
        if pkChanged, !primaryKey.isEmpty {
            result.append(.setPrimaryKey(primaryKey))
        }
        result.append(contentsOf: addedIndexChanges())
        result.append(contentsOf: addedForeignKeys.map { .addForeignKey($0) })
        result.append(contentsOf: addedChecks.map { .addCheck($0) })
        if !tableOptions.isEmpty {
            result.append(.setTableOptions(tableOptions))
        }
        return result
    }

    public var hasChanges: Bool {
        !changes().isEmpty
    }

    // MARK: - Column diff

    private func droppedColumnChanges() -> [SchemaChange] {
        let keptOriginals = Set(columns.compactMap(\.originalName))
        return originalColumns
            .filter { !keptOriginals.contains($0.name) }
            .map { .dropColumn($0.name) }
    }

    private func modifiedColumnChanges() -> [SchemaChange] {
        columns.compactMap { column in
            guard let original = column.originalName,
                  let match = originalColumns.first(where: { $0.name == original }),
                  !match.hasSameDefinition(as: column)
            else { return nil }
            return .modifyColumn(original: original, column)
        }
    }

    private func addedColumnChanges() -> [SchemaChange] {
        columns
            .filter { $0.originalName == nil }
            .map { .addColumn($0, after: nil) }
    }

    // MARK: - Index diff

    private func droppedIndexChanges() -> [SchemaChange] {
        var result: [SchemaChange] = []
        for original in originalIndexes where original.name != "PRIMARY" {
            if let working = indexes.first(where: { $0.name == original.name }) {
                if !sameIndex(original, working) {
                    result.append(.dropIndex(original.name))
                }
            } else {
                result.append(.dropIndex(original.name))
            }
        }
        return result
    }

    private func addedIndexChanges() -> [SchemaChange] {
        indexes.compactMap { working in
            if let original = originalIndexes.first(where: { $0.name == working.name }) {
                return sameIndex(original, working) ? nil : .addIndex(working)
            }
            return .addIndex(working)
        }
    }

    private func sameIndex(_ lhs: IndexDraft, _ rhs: IndexDraft) -> Bool {
        lhs.columns == rhs.columns && lhs.isUnique == rhs.isUnique
    }

    // MARK: - Metadata mapping

    static func draft(from column: ColumnInfo) -> ColumnDraft {
        let generated = column.generationExpression.map {
            GeneratedColumn(expression: $0, kind: column.generationStored ? .stored : .virtual)
        }
        return ColumnDraft(
            name: column.name,
            type: column.dataType,
            isNullable: column.isNullable,
            isAutoIncrement: column.isAutoIncrement,
            defaultValue: mapDefault(
                column.defaultValue,
                generated: generated != nil,
                isExpression: column.defaultIsExpression
            ),
            onUpdateCurrentTimestamp: column.onUpdateCurrentTimestamp,
            charset: column.charset,
            collation: column.collation,
            comment: column.comment,
            generated: generated,
            originalName: column.name
        )
    }

    static func mapDefault(_ raw: String?, generated: Bool, isExpression: Bool = false) -> ColumnDefault {
        guard !generated, let raw else { return .none }
        let upper = raw.uppercased()
        if upper == "CURRENT_TIMESTAMP" || upper.hasPrefix("CURRENT_TIMESTAMP(") {
            return .currentTimestamp
        }
        // EXTRA = DEFAULT_GENERATED: COLUMN_DEFAULT là biểu thức, không phải literal.
        if isExpression {
            return .expression(raw)
        }
        if Double(raw) != nil {
            return .number(raw)
        }
        return .text(raw)
    }
}
