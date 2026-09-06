import AppKit

extension KTDataGrid.Coordinator {
    func cellIsInlineEditable(row: Int, column: Int) -> Bool {
        guard row < result.rows.count, column > 0 else { return false }
        let dataCol = column - 1
        guard dataCol < result.columns.count else { return false }
        return editableColumns.contains(result.columns[dataCol].name)
    }

    func cellDisplayText(row: Int, column: Int) -> String {
        guard row < result.rows.count, column > 0 else { return "" }
        let dataCol = column - 1
        guard dataCol < result.columns.count, dataCol < result.rows[row].count else { return "" }
        return result.rows[row][dataCol].displayText ?? ""
    }

    func handleActiveCellChanged(_ active: (row: Int, column: Int)?) {
        if let active, active.row >= 0, active.row < result.rows.count {
            selectedRow?.wrappedValue = active.row
        } else {
            selectedRow?.wrappedValue = nil
        }
    }
}
