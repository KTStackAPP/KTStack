import Foundation

public extension DatabaseV2ViewModel {
    var canEdit: Bool {
        capabilities.canEditRows && !columns.primaryKeyColumns.isEmpty
    }

    var editableColumns: Set<String> {
        guard canEdit else { return [] }
        let pkNames = Set(columns.primaryKeyColumns.map(\.name))
        let binaryNames = Set(columns.filter { CellEditorKind.forColumn($0) == .binary }.map(\.name))
        return Set(columns.map(\.name)).subtracting(pkNames).subtracting(binaryNames)
    }

    /// Rows with staged updates applied, so inline edits show before commit. Index-aligned with `rows`.
    var displayRows: QueryResult? {
        guard let rows else { return nil }
        let base = staged?.displayResult(base: rows) ?? rows
        guard insertDraft != nil else { return base }
        let draftRow = draftDisplayRow(columns: base.columns)
        return QueryResult(
            columns: base.columns, rows: base.rows + [draftRow],
            truncated: base.truncated, estimatedTotal: base.estimatedTotal
        )
    }

    /// Sửa ô grid: dòng nháp insert (index cuối) đi vào draft, còn lại vào staged buffer.
    func stageOrDraftEdit(row: Int, column: Int, edit: CellEdit) {
        if let draftIndex = insertDraftRowIndex, row == draftIndex {
            editDraftCell(column: column, edit: edit)
        } else {
            stageCellEdit(row: row, column: column, edit: edit)
        }
    }

    func stageOrDraftEdit(row: Int, column: Int, value: String) {
        stageOrDraftEdit(row: row, column: column, edit: .value(value))
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
        await ensureConnected()
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
    func deleteRowOrCancelDraft(row: Int) {
        if let draftIndex = insertDraftRowIndex, row == draftIndex {
            cancelInsertDraft()
            return
        }
        stageDelete(row: row)
    }

    func undoOrCancelDraft() {
        if isDraftingInsert {
            cancelInsertDraft()
            return
        }
        undoStaged()
    }

    func commitAllStagedAndDraft() async {
        if isDraftingInsert {
            commitInsertDraft()
        }
        await commitStaged()
    }

    var modifiedCellCoords: Set<CellCoord> {
        guard let base = rows, let display = displayRows else { return [] }
        var result: Set<CellCoord> = []
        let rowCount = min(base.rows.count, display.rows.count)
        for row in 0..<rowCount {
            let colCount = min(base.rows[row].count, display.rows[row].count)
            for col in 0..<colCount {
                if base.rows[row][col] != display.rows[row][col] {
                    result.insert(CellCoord(row: row, column: col))
                }
            }
        }
        return result
    }

    var stagedDeleteRowIndices: Set<Int> {
        guard let staged, let base = rows else { return [] }
        return staged.stagedDeleteRows(in: base)
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
