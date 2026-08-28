import AppKit

extension KTDataGrid.Coordinator: KTGridInput {
    func gridSelect(viewRow: Int, viewColumn: Int, extending: Bool) {
        guard viewRow >= 0, viewRow < result.rows.count, !result.columns.isEmpty else { return }
        if viewColumn == 0 {
            if extending, !selection.isEmpty {
                selection.extend(toRow: viewRow, column: result.columns.count - 1)
            } else {
                selection.selectRow(viewRow, columnCount: result.columns.count)
            }
        } else {
            let column = viewColumn - 1
            guard column < result.columns.count else { return }
            if extending, !selection.isEmpty {
                selection.extend(toRow: viewRow, column: column)
            } else {
                selection.selectCell(row: viewRow, column: column)
            }
        }
        refreshSelectionUI()
    }

    func gridExtend(viewRow: Int, viewColumn: Int) {
        guard viewRow >= 0, viewRow < result.rows.count, !result.columns.isEmpty else { return }
        let column = viewColumn == 0 ? result.columns.count - 1 : min(viewColumn - 1, result.columns.count - 1)
        selection.extend(toRow: viewRow, column: max(0, column))
        refreshSelectionUI()
    }

    func gridMoveFocus(rowDelta: Int, columnDelta: Int, extending: Bool) {
        guard !result.rows.isEmpty, !result.columns.isEmpty else { return }
        let current = selection.focus ?? GridCell(row: 0, column: 0)
        let row = min(max(0, current.row + rowDelta), result.rows.count - 1)
        let column = min(max(0, current.column + columnDelta), result.columns.count - 1)
        if extending, !selection.isEmpty {
            selection.extend(toRow: row, column: column)
        } else {
            selection.selectCell(row: row, column: column)
        }
        refreshSelectionUI()
        ensureVisible(row: row, column: column)
    }

    func gridSelectAll() {
        selection.selectAll(rowCount: result.rows.count, columnCount: result.columns.count)
        refreshSelectionUI()
    }

    func gridDoubleClick(viewRow: Int, viewColumn: Int) {
        gridSelect(viewRow: viewRow, viewColumn: viewColumn, extending: false)
        guard let column = dataIndex(ofViewColumn: viewColumn), cellIsInlineEditable(row: viewRow, column: column) else {
            if viewRow < result.rows.count { onActivate?(viewRow) }
            return
        }
        beginInlineEdit(row: viewRow, viewColumn: viewColumn, dataColumn: column)
    }

    func gridBeginEditFocus() {
        guard let focus = selection.focus, focus.row < result.rows.count,
              cellIsInlineEditable(row: focus.row, column: focus.column) else { return }
        beginInlineEdit(row: focus.row, viewColumn: focus.column + 1, dataColumn: focus.column)
    }

    func gridCopy() { copyCells(format: .tsv) }

    func gridPaste() {}

    func refreshSelectionUI() {
        guard let table, let overlay else { return }
        overlay.frame = table.bounds
        guard let rowRange = selection.rowRange, let columnRange = selection.columnRange else {
            overlay.selectionRect = nil
            overlay.focusRect = nil
            selectedRow?.wrappedValue = nil
            return
        }
        overlay.selectionRect = cellRect(rows: rowRange, columns: columnRange)
        if let focus = selection.focus {
            overlay.focusRect = cellRect(rows: focus.row...focus.row, columns: focus.column...focus.column)
        }
        selectedRow?.wrappedValue = rowRange.count == 1 ? rowRange.lowerBound : nil
    }

    func clampSelection() {
        guard !selection.isEmpty else { return }
        if result.rows.isEmpty || result.columns.isEmpty {
            selection.clear()
        } else if let rowRange = selection.rowRange,
                  rowRange.upperBound >= result.rows.count || (selection.columnRange?.upperBound ?? 0) >= result.columns.count {
            selection.clear()
        }
        refreshSelectionUI()
    }

    private func cellRect(rows: ClosedRange<Int>, columns: ClosedRange<Int>) -> NSRect {
        guard let table else { return .zero }
        let top = table.frameOfCell(atColumn: columns.lowerBound + 1, row: rows.lowerBound)
        let bottom = table.frameOfCell(atColumn: columns.upperBound + 1, row: rows.upperBound)
        return top.union(bottom)
    }

    private func ensureVisible(row: Int, column: Int) {
        guard let table else { return }
        table.scrollRowToVisible(row)
        table.scrollColumnToVisible(column + 1)
    }

    func selectionRowsColumns() -> (rows: [Int], columns: [Int]) {
        if let rowRange = selection.rowRange, let columnRange = selection.columnRange {
            return (Array(rowRange), Array(columnRange))
        }
        return (Array(result.rows.indices), Array(result.columns.indices))
    }

    func copyCells(format: GridCopyFormat) {
        let (rows, columns) = selectionRowsColumns()
        let text = GridCopySerializer().serialize(result, rows: rows, columns: columns, format: format)
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
    }
}
