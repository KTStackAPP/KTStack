import Foundation

/// Ngữ cảnh cho sheet sửa ô lớn (JSON sửa được + validate, binary chỉ xem).
public struct V2CellEditorContext: Identifiable, Equatable {
    public let id = UUID()
    public let row: Int
    public let column: Int
    public let columnName: String
    public let isBinary: Bool
    public let text: String
}

public extension DatabaseV2ViewModel {
    func openCellEditor(row: Int, column: Int) {
        guard let result = displayRows, row >= 0, row < result.rows.count,
              column >= 0, column < result.columns.count else { return }
        let name = result.columns[column].name
        let cell = result.rows[row][column]
        switch columnEditorKind(name) {
        case .json:
            cellEditor = V2CellEditorContext(
                row: row, column: column, columnName: name, isBinary: false, text: cell.displayText ?? ""
            )
        case .binary:
            cellEditor = V2CellEditorContext(
                row: row, column: column, columnName: name, isBinary: true, text: binaryPreview(cell)
            )
        default:
            break
        }
    }

    func saveCellEditor(text: String) {
        guard let context = cellEditor else { return }
        stageCellEdit(row: context.row, column: context.column, edit: .value(text))
        cellEditor = nil
    }

    func closeCellEditor() {
        cellEditor = nil
    }

    private func columnEditorKind(_ name: String) -> CellEditorKind {
        guard let column = columns.first(where: { $0.name == name }) else { return .text }
        return CellEditorKind.forColumn(column)
    }

    private func binaryPreview(_ cell: Cell) -> String {
        guard case let .blob(data) = cell else { return cell.displayText ?? "" }
        if let utf8 = String(data: data, encoding: .utf8) { return utf8 }
        let hex = data.prefix(512).map { String(format: "%02x", $0) }.joined(separator: " ")
        return data.count > 512 ? "\(hex) … (\(data.count) bytes)" : hex
    }
}
