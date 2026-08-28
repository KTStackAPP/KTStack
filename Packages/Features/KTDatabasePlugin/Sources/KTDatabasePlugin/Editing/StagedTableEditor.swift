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

    public func setDraftValue(_ id: DraftRowID, column: String, edit: CellEdit) throws {
        guard let info = columnByName[column] else { return }
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
