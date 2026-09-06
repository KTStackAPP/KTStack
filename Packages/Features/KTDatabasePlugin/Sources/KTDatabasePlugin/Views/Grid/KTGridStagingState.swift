import Foundation

public struct CellCoord: Hashable, Equatable, Sendable {
    public let row: Int
    public let column: Int

    public init(row: Int, column: Int) {
        self.row = row
        self.column = column
    }
}

public struct RowKey: Hashable, Equatable, Sendable {
    public let values: [String: Cell]

    public init(values: [String: Cell]) {
        self.values = values
    }

    public static func extract(from row: [String: Cell], primaryKeyColumns: [String]) -> RowKey? {
        guard !primaryKeyColumns.isEmpty else { return nil }
        var keyValues: [String: Cell] = [:]
        for col in primaryKeyColumns {
            guard let cell = row[col], cell != .null else { return nil }
            keyValues[col] = cell
        }
        return RowKey(values: keyValues)
    }

    public static func extract(from cells: [Cell], columns: [ColumnMeta], primaryKeyColumns: [String]) -> RowKey? {
        guard !primaryKeyColumns.isEmpty, cells.count == columns.count else { return nil }
        var dict: [String: Cell] = [:]
        for (index, col) in columns.enumerated() {
            dict[col.name] = cells[index]
        }
        return extract(from: dict, primaryKeyColumns: primaryKeyColumns)
    }
}

public final class KTGridStagingState: @unchecked Sendable {
    public private(set) var modifiedCells: [RowKey: [String: String]] = [:]
    public private(set) var insertedRows: [UUID: [String: String]] = [:]
    public private(set) var deletedRowKeys: Set<RowKey> = []

    public init() {}

    public var hasPendingChanges: Bool {
        !modifiedCells.isEmpty || !insertedRows.isEmpty || !deletedRowKeys.isEmpty
    }

    public var pendingCount: Int {
        modifiedCells.count + insertedRows.count + deletedRowKeys.count
    }

    public func isCellModified(rowKey: RowKey, column: String) -> Bool {
        modifiedCells[rowKey]?[column] != nil
    }

    public func modifiedValue(rowKey: RowKey, column: String) -> String? {
        modifiedCells[rowKey]?[column]
    }

    public func isRowDeleted(rowKey: RowKey) -> Bool {
        deletedRowKeys.contains(rowKey)
    }

    public func isDraftRow(id: UUID) -> Bool {
        insertedRows[id] != nil
    }

    public func stageEdit(key: RowKey, column: String, value: String) {
        guard !deletedRowKeys.contains(key) else { return }
        modifiedCells[key, default: [:]][column] = value
    }

    public func clearEdit(key: RowKey, column: String) {
        modifiedCells[key]?[column] = nil
        if modifiedCells[key]?.isEmpty == true {
            modifiedCells[key] = nil
        }
    }

    @discardableResult
    public func stageInsert(id: UUID = UUID(), values: [String: String] = [:]) -> UUID {
        insertedRows[id] = values
        return id
    }

    public func updateInsert(id: UUID, column: String, value: String) {
        insertedRows[id, default: [:]][column] = value
    }

    public func removeInsert(id: UUID) {
        insertedRows[id] = nil
    }

    public func stageDelete(key: RowKey) {
        modifiedCells[key] = nil
        deletedRowKeys.insert(key)
    }

    public func unstageDelete(key: RowKey) {
        deletedRowKeys.remove(key)
    }

    public func discardAll() {
        modifiedCells.removeAll()
        insertedRows.removeAll()
        deletedRowKeys.removeAll()
    }
}
