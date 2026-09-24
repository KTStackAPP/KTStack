import Foundation

public extension DatabaseV2ViewModel {
    func rowRef(at row: Int) -> GridRowRef? {
        if let draftIndex = insertDraftRowIndex, row == draftIndex { return .draft }
        guard let table = selectedTable, let result = rows, row >= 0, row < result.rows.count else { return nil }
        return .row(table: table.name, values: rowDict(result, row))
    }

    func stageOrDraftEdit(ref: GridRowRef, column: String, value: String) {
        guard let columnIndex = rows?.columns.firstIndex(where: { $0.name == column }) else { return }
        switch ref {
        case .draft:
            editDraftCell(column: columnIndex, edit: .value(value))
        case let .row(table, values):
            guard let editor = staged, selectedTable?.name == table else { return }
            editError = nil
            do {
                try editor.stageUpdate(row: values, column: column, edit: .value(value))
                refreshStagedState()
            } catch {
                editError = error.localizedDescription
            }
        }
    }
}
