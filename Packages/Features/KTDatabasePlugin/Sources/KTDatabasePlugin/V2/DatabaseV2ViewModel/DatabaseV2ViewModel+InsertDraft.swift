import Foundation

/// Insert dòng mới inline theo design: một dòng nháp hiện ở cuối grid (qua displayRows), sửa từng ô,
/// rồi "Stage row" đẩy vào staged buffer như một pending change (áp khi Commit). Không đụng KTDataGrid.
public extension DatabaseV2ViewModel {
    var isDraftingInsert: Bool { insertDraft != nil }

    func beginInsertDraft() {
        guard canEdit, selectedTable != nil else { return }
        insertDraft = [:]
        editError = nil
    }

    func cancelInsertDraft() {
        insertDraft = nil
    }

    /// Chỉ số dòng nháp trong displayRows (== số dòng thực), hoặc nil nếu không có nháp.
    var insertDraftRowIndex: Int? {
        guard insertDraft != nil, let rows else { return nil }
        return rows.rowCount
    }

    func editDraftCell(column: Int, edit: CellEdit) {
        guard insertDraft != nil, let rows, column >= 0, column < rows.columns.count else { return }
        let name = rows.columns[column].name
        insertDraft?[name] = edit
    }

    func commitInsertDraft() {
        guard let draft = insertDraft else { return }
        var values: [ColumnValue] = []
        for column in columns {
            guard let edit = draft[column.name] else { continue }
            switch edit {
            case let .value(text): values.append(ColumnValue(column: column.name, value: .text(text)))
            case .null: values.append(ColumnValue(column: column.name, value: .null))
            case .empty: values.append(ColumnValue(column: column.name, value: .text("")))
            case .default: values.append(ColumnValue(defaultFor: column.name))
            case .now:
                let stamp = CellCoercion.timestampString(kind: .forColumn(column))
                values.append(ColumnValue(column: column.name, value: .text(stamp)))
            }
        }
        stageInsertRow(values)
        insertDraft = nil
    }

    /// Dòng hiển thị cho nháp insert: theo thứ tự cột, ô chưa đặt hiện NULL.
    func draftDisplayRow(columns metas: [ColumnMeta]) -> [Cell] {
        let draft = insertDraft ?? [:]
        return metas.map { meta in
            switch draft[meta.name] {
            case let .value(text): .text(text)
            case .empty: .text("")
            case .null: .null
            case .default: .text("(default)")
            case .now: .text("(now)")
            case nil: .null
            }
        }
    }
}
