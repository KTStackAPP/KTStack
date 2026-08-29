import KTPluginKit
import SwiftUI

/// Panel phải: chi tiết dòng đang chọn (sửa inline, NULL toggle) và FK liên quan. Thay V2RowEditorSheet.
struct WorkspaceInspector: View {
    @ObservedObject var vm: DatabaseV2ViewModel
    @Binding var selectedRow: Int?

    var body: some View {
        VStack(spacing: 0) {
            header
            if let row = selectedRow, let result = vm.displayRows, row >= 0, row < result.rows.count {
                content(columns: result.columns, cells: result.rows[row], rowIndex: row)
            } else {
                placeholder
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(KTEditorTheme.content2)
    }

    private var header: some View {
        HStack {
            Text("Chi tiết dòng")
                .font(.jbMono(12.5, .bold))
                .foregroundStyle(KTEditorTheme.label)
            Spacer()
            if let row = selectedRow {
                Text("#\(vm.windowStart + row + 1)")
                    .font(.jbMono(11))
                    .foregroundStyle(KTEditorTheme.label3)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
        .overlay(alignment: .bottom) { Divider().overlay(KTEditorTheme.separator) }
    }

    private var placeholder: some View {
        VStack {
            Spacer()
            Text("Chọn một dòng")
                .font(.jbMono(12))
                .foregroundStyle(KTEditorTheme.label3)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    private func content(columns: [ColumnMeta], cells: [Cell], rowIndex: Int) -> some View {
        ScrollView {
            VStack(spacing: 0) {
                ForEach(Array(columns.enumerated()), id: \.offset) { index, col in
                    InspectorField(
                        columnName: col.name,
                        cell: index < cells.count ? cells[index] : .null,
                        editable: vm.canEdit && vm.editableColumns.contains(col.name),
                        onCommit: { text in vm.stageOrDraftEdit(row: rowIndex, column: index, value: text) },
                        onSetNull: { vm.stageOrDraftEdit(row: rowIndex, column: index, edit: .null) }
                    )
                    .id("\(rowIndex)-\(col.name)")
                }
                relatedForeignKeys(rowIndex: rowIndex, columns: columns)
            }
        }
    }

    @ViewBuilder
    private func relatedForeignKeys(rowIndex: Int, columns: [ColumnMeta]) -> some View {
        let relations = vm.foreignKeys.filter { $0.fromTable == vm.selectedTable?.name }
        if !relations.isEmpty {
            VStack(alignment: .leading, spacing: 6) {
                Text("Khóa ngoại")
                    .font(.jbMono(11, .semibold))
                    .foregroundStyle(KTEditorTheme.label2)
                ForEach(relations) { relation in
                    if let column = columns.firstIndex(where: { $0.name == relation.fromColumn }) {
                        Button {
                            vm.navigateForeignKey(row: rowIndex, column: column)
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "arrow.turn.down.right").font(.system(size: 10))
                                Text("\(relation.fromColumn) → \(relation.toTable)")
                                    .font(.jbMono(11))
                            }
                            .foregroundStyle(KTEditorTheme.accent)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
        }
    }
}

/// Một trường trong inspector: sửa inline (TextEditor cho chuỗi dài), nút NULL. Reset khi đổi dòng qua .id.
private struct InspectorField: View {
    let columnName: String
    let cell: Cell
    let editable: Bool
    let onCommit: (String) -> Void
    let onSetNull: () -> Void

    @State private var text: String
    @FocusState private var focused: Bool

    init(columnName: String, cell: Cell, editable: Bool, onCommit: @escaping (String) -> Void, onSetNull: @escaping () -> Void) {
        self.columnName = columnName
        self.cell = cell
        self.editable = editable
        self.onCommit = onCommit
        self.onSetNull = onSetNull
        _text = State(initialValue: cell.displayText ?? "")
    }

    private var isMultiline: Bool { (cell.displayText?.count ?? 0) > 60 }

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack {
                Text(columnName)
                    .font(.jbMono(11, .semibold))
                    .foregroundStyle(KTEditorTheme.label2)
                Spacer()
                if editable {
                    Button("NULL") { onSetNull() }
                        .buttonStyle(.plain)
                        .font(.jbMono(9.5))
                        .foregroundStyle(KTEditorTheme.label3)
                }
            }
            if editable {
                editor
            } else {
                staticValue
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .overlay(alignment: .bottom) { Divider().overlay(KTEditorTheme.separator) }
    }

    @ViewBuilder
    private var editor: some View {
        if isMultiline {
            TextEditor(text: $text)
                .font(.jbMono(11.5))
                .frame(height: 80)
                .focused($focused)
                .onChange(of: focused) { isFocused in if !isFocused { onCommit(text) } }
        } else {
            TextField("", text: $text)
                .textFieldStyle(.plain)
                .font(.jbMono(12))
                .focused($focused)
                .onSubmit { onCommit(text) }
                .onChange(of: focused) { isFocused in if !isFocused { onCommit(text) } }
        }
    }

    @ViewBuilder
    private var staticValue: some View {
        switch cell {
        case .null:
            Text("NULL").font(.jbMono(12)).italic().foregroundStyle(KTEditorTheme.faint)
        case let .int(n):
            Text(String(n)).font(.jbMono(12)).foregroundStyle(KTEditorTheme.Grid.number)
        case let .double(d):
            Text(String(d)).font(.jbMono(12)).foregroundStyle(KTEditorTheme.Grid.number)
        case let .bool(b):
            Text(b ? "true" : "false").font(.jbMono(12)).foregroundStyle(KTEditorTheme.label)
        case let .text(s):
            Text(s).font(.jbMono(12)).foregroundStyle(KTEditorTheme.label)
        case let .blob(d):
            Text("[\(d.count) bytes]").font(.jbMono(12)).italic().foregroundStyle(KTEditorTheme.faint)
        }
    }
}
