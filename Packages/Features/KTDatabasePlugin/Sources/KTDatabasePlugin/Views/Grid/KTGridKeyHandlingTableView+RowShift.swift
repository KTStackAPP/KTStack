import AppKit

extension KTGridKeyHandlingTableView {
    static func shiftedRow(_ row: Int, by delta: Int, rowCount: Int) -> Int? {
        let shifted = row + delta
        return shifted >= 0 && shifted < rowCount ? shifted : nil
    }

    func shiftActiveCell(by delta: Int) {
        guard delta != 0, let active = activeCell else { return }
        guard let row = Self.shiftedRow(active.row, by: delta, rowCount: numberOfRows) else {
            deselectAll(nil)
            clearActiveCell()
            return
        }
        activeCell = (row, active.column)
        selectRowIndexes(IndexSet(integer: row), byExtendingSelection: false)
        onActiveCellChanged?(activeCell)
    }
}
