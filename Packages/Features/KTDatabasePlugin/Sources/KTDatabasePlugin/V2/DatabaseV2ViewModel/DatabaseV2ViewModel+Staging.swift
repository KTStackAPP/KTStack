import Foundation

public extension DatabaseV2ViewModel {
    var canEdit: Bool {
        capabilities.canEditRows && !columns.primaryKeyColumns.isEmpty
    }

    var editableColumns: Set<String> {
        guard canEdit else { return [] }
        let pkNames = Set(columns.primaryKeyColumns.map(\.name))
        return Set(columns.map(\.name)).subtracting(pkNames)
    }

    /// Rows with staged updates applied, so inline edits show before commit. Index-aligned with `rows`.
    var displayRows: QueryResult? {
        guard let rows else { return nil }
        return staged?.displayResult(base: rows) ?? rows
    }

    func rebuildStagedEditor() {
        guard let driver, let database = selectedDatabase, let table = selectedTable, !columns.isEmpty else {
            staged = nil
            refreshStagedState()
            return
        }
        staged = StagedTableEditor(
            schema: database,
            table: table.name,
            dialect: .forKind(connectionKind ?? .mysql),
            columns: columns,
            uniqueIndexes: indexes.filter(\.isUnique),
            driver: driver,
            database: database
        )
        refreshStagedState()
    }

    func stageCellEdit(row: Int, column: Int, newValue: String) {
        stageCellEdit(row: row, column: column, edit: .value(newValue))
    }

    func stageCellEdit(row: Int, column: Int, edit: CellEdit) {
        guard let editor = staged, let result = rows,
              row >= 0, row < result.rows.count,
              column >= 0, column < result.columns.count else { return }
        editError = nil
        do {
            try editor.stageUpdate(row: rowDict(result, row), column: result.columns[column].name, edit: edit)
            refreshStagedState()
        } catch {
            editError = error.localizedDescription
        }
    }

    func stageDelete(row: Int) {
        guard let editor = staged, let result = rows, row >= 0, row < result.rows.count else { return }
        editError = nil
        do {
            try editor.stageDelete(row: rowDict(result, row))
            refreshStagedState()
        } catch {
            editError = error.localizedDescription
        }
    }

    func stagePaste(_ cells: [PastedCell]) {
        guard let editor = staged, let result = rows, !cells.isEmpty else { return }
        editError = nil
        let names = result.columns.map(\.name)
        let dictRows = result.rows.indices.map { rowDict(result, $0) }
        do {
            try editor.applyPaste(cells, rows: dictRows, columnNames: names)
            refreshStagedState()
        } catch {
            editError = error.localizedDescription
        }
    }

    func stageInsertRow(_ values: [ColumnValue]) {
        guard let editor = staged else { return }
        editor.stageInsert(values: values)
        refreshStagedState()
    }

    func commitStaged() async {
        guard let editor = staged, editor.hasPendingChanges else { return }
        let token = generation
        isCommitting = true
        editError = nil
        do {
            try await editor.commit()
            guard token == generation else { isCommitting = false; return }
            await reloadLoaded()
            refreshStagedState()
        } catch {
            guard token == generation else { isCommitting = false; return }
            editError = error.localizedDescription
        }
        isCommitting = false
    }

    func discardStaged() {
        staged?.discardAll()
        refreshStagedState()
    }

    func undoStaged() {
        staged?.undo()
        refreshStagedState()
    }

    func redoStaged() {
        staged?.redo()
        refreshStagedState()
    }

    func refreshStagedState() {
        pendingChangeCount = staged?.pendingCount ?? 0
        canUndoStaged = staged?.canUndo ?? false
        canRedoStaged = staged?.canRedo ?? false
    }

    private func rowDict(_ result: QueryResult, _ row: Int) -> [String: Cell] {
        var dict: [String: Cell] = [:]
        let names = result.columns.map(\.name)
        for (index, name) in names.enumerated() where index < result.rows[row].count {
            dict[name] = result.rows[row][index]
        }
        return dict
    }
}
