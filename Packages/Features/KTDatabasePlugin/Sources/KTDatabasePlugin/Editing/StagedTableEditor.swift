import Foundation

/// Ties the pure staging pieces together for one table: coerces typed edits into cells, resolves each
/// row's identity, buffers updates/deletes/inserts with undo/redo, previews the batch as redacted SQL
/// and commits it in one guarded transaction. Holds no AppKit; the view model drives it.
public final class StagedTableEditor {
    public let schema: String
    public let table: String
    public let columns: [ColumnInfo]

    private let resolver: RowIdentityResolver
    private let planner: RelationalWritePlanner
    private let executor: RelationalWriteExecutor
    private let buffer = GridEditBuffer()
    private let columnByName: [String: ColumnInfo]

    public init(
        schema: String,
        table: String,
        dialect: SQLDialect,
        columns: [ColumnInfo],
        uniqueIndexes: [IndexInfo] = [],
        driver: any RelationalDriver,
        database: String
    ) {
        self.schema = schema
        self.table = table
        self.columns = columns
        columnByName = Dictionary(columns.map { ($0.name, $0) }, uniquingKeysWith: { first, _ in first })
        resolver = RowIdentityResolver(columns: columns, uniqueIndexes: uniqueIndexes)
        planner = RelationalWritePlanner(dialect: dialect, schema: schema, table: table)
        executor = RelationalWriteExecutor(driver: driver, database: database)
    }

    public var hasPendingChanges: Bool { buffer.hasPendingChanges }
    public var pendingCount: Int { buffer.pendingCount }
    public var canUndo: Bool { buffer.canUndo }
    public var canRedo: Bool { buffer.canRedo }

    /// Stages an update to an existing row. Returns false when the coerced value equals the current
    /// one (no-op). Throws when the row has no usable key or the value fails column constraints.
    @discardableResult
    public func stageUpdate(row: [String: Cell], column: String, edit: CellEdit) throws -> Bool {
        guard let info = columnByName[column] else { return false }
        guard let identity = resolver.identity(for: row) else {
            throw DatabaseError.connection("Can't identify this row to edit (no key).")
        }
        if edit == .default {
            buffer.stageDefault(identity: identity, column: column)
            return true
        }
        let value = try CellCoercion.cell(for: edit, column: info, kind: .forColumn(info))
        if let current = row[column], current == value { return false }
        buffer.stageUpdate(identity: identity, column: column, value: value)
        return true
    }

    public func stageDelete(row: [String: Cell]) throws {
        guard let identity = resolver.identity(for: row) else {
            throw DatabaseError.connection("Can't identify this row to delete (no key).")
        }
        buffer.stageDelete(identity: identity)
    }

    public func unstageDelete(row: [String: Cell]) {
        if let identity = resolver.identity(for: row) {
            buffer.unstageDelete(identity: identity)
        }
    }

    @discardableResult
    public func beginInsert() -> DraftRowID {
        buffer.stageInsert()
    }

    @discardableResult
    public func stageInsert(values: [ColumnValue]) -> DraftRowID {
        let id = buffer.stageInsert()
        for value in values {
            buffer.setDraftValue(id, column: value.column, value: value.value)
        }
        return id
    }

    public func setDraftValue(_ id: DraftRowID, column: String, edit: CellEdit) throws {
        guard let info = columnByName[column] else { return }
        if edit == .default {
            buffer.setDraftDefault(id, column: column)
            return
        }
        let value = try CellCoercion.cell(for: edit, column: info, kind: .forColumn(info))
        buffer.setDraftValue(id, column: column, value: value)
    }

    public func removeDraft(_ id: DraftRowID) {
        buffer.removeDraft(id)
    }

    /// Applies already-validated pasted cells as updates to existing rows. The paste shape is checked
    /// by `GridPasteParser` first; here each cell coerces and stages. Returns how many changed.
    @discardableResult
    public func applyPaste(_ cells: [PastedCell], rows: [[String: Cell]], columnNames: [String]) throws -> Int {
        var staged = 0
        for cell in cells {
            guard rows.indices.contains(cell.row), columnNames.indices.contains(cell.column) else { continue }
            if try stageUpdate(row: rows[cell.row], column: columnNames[cell.column], edit: .value(cell.value)) {
                staged += 1
            }
        }
        return staged
    }

    /// Applies staged updates onto the base rows in place (same count and order) so the grid shows
    /// pending edits immediately. Deletes and inserts stay pending until commit; row indices are kept
    /// stable so the caller's index -> row mapping still holds.
    public func displayResult(base: QueryResult) -> QueryResult {
        guard hasPendingChanges else { return base }
        let names = base.columns.map(\.name)
        let rows = base.rows.map { cells -> [Cell] in
            var dict: [String: Cell] = [:]
            for (index, name) in names.enumerated() where index < cells.count { dict[name] = cells[index] }
            guard let identity = resolver.identity(for: dict) else { return cells }
            let changes = buffer.stagedUpdate(for: identity)
            let defaults = buffer.stagedDefaults(for: identity)
            guard changes != nil || !defaults.isEmpty else { return cells }
            var updated = cells
            for (index, name) in names.enumerated() where index < updated.count {
                if defaults.contains(name) {
                    updated[index] = .text("(default)")
                } else if let value = changes?[name] {
                    updated[index] = value
                }
            }
            return updated
        }
        return QueryResult(columns: base.columns, rows: rows, truncated: base.truncated, estimatedTotal: base.estimatedTotal)
    }

    /// Row indices in `base` staged for deletion, for the grid to mark (D3 styling).
    public func stagedDeleteRows(in base: QueryResult) -> Set<Int> {
        guard hasPendingChanges else { return [] }
        let names = base.columns.map(\.name)
        var result: Set<Int> = []
        for (rowIndex, cells) in base.rows.enumerated() {
            var dict: [String: Cell] = [:]
            for (index, name) in names.enumerated() where index < cells.count { dict[name] = cells[index] }
            if let identity = resolver.identity(for: dict), buffer.isStagedDelete(identity) {
                result.insert(rowIndex)
            }
        }
        return result
    }

    public func undo() { buffer.undo() }
    public func redo() { buffer.redo() }
    public func discardAll() { buffer.discardAll() }

    public func sqlPreview() throws -> SQLPreview {
        try planner.preview(buffer.operations())
    }

    public func commit() async throws {
        let operations = buffer.operations()
        guard !operations.isEmpty else { return }
        let steps = try planner.plan(operations)
        try await executor.commit(steps)
        buffer.markCommitted()
    }
}
