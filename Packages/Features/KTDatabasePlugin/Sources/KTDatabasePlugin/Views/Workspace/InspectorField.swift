import KTPluginKit
import SwiftUI

struct InspectorField: View {
    let columnName: String
    let dataType: String
    let isPrimaryKey: Bool
    let isForeignKey: Bool
    let cell: Cell
    let isModified: Bool
    let editable: Bool
    let onCommit: (String) -> Void
    let onSetNull: () -> Void

    @State private var text: String
    @FocusState private var focused: Bool

    init(
        columnName: String,
        dataType: String,
        isPrimaryKey: Bool,
        isForeignKey: Bool,
        cell: Cell,
        isModified: Bool,
        editable: Bool,
        onCommit: @escaping (String) -> Void,
        onSetNull: @escaping () -> Void
    ) {
        self.columnName = columnName
        self.dataType = dataType
        self.isPrimaryKey = isPrimaryKey
        self.isForeignKey = isForeignKey
        self.cell = cell
        self.isModified = isModified
        self.editable = editable
        self.onCommit = onCommit
        self.onSetNull = onSetNull
        _text = State(initialValue: cell.displayText ?? "")
    }

    private var isMultiline: Bool { (cell.displayText?.count ?? 0) > 60 }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Text(columnName)
                    .font(.jbMono(11, .semibold))
                    .foregroundStyle(KTEditorTheme.label2)
                if isPrimaryKey {
                    Text("PK")
                        .font(.jbMono(8.5, .bold))
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background(KTEditorTheme.accent.opacity(0.15))
                        .foregroundStyle(KTEditorTheme.accent)
                        .cornerRadius(3)
                }
                if isForeignKey {
                    Text("FK")
                        .font(.jbMono(8.5, .bold))
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background(Color.blue.opacity(0.15))
                        .foregroundStyle(Color.blue)
                        .cornerRadius(3)
                }
                Text(dataType)
                    .font(.jbMono(9.5))
                    .foregroundStyle(KTEditorTheme.faint)
                Spacer()
                if isModified {
                    Circle()
                        .fill(Color.orange)
                        .frame(width: 6, height: 6)
                }
                if editable {
                    Button("NULL") { text = ""; onSetNull() }
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
        .onChange(of: cell) { newCell in
            if !focused {
                text = newCell.displayText ?? ""
            }
        }
    }

    @ViewBuilder
    private var editor: some View {
        if isMultiline {
            TextEditor(text: $text)
                .font(.jbMono(11.5))
                .frame(height: 70)
                .focused($focused)
                .onChange(of: focused) { isFocused in
                    if !isFocused && text != (cell.displayText ?? "") { onCommit(text) }
                }
        } else {
            TextField("", text: $text)
                .textFieldStyle(.plain)
                .font(.jbMono(12))
                .focused($focused)
                .onSubmit { onCommit(text) }
                .onChange(of: focused) { isFocused in
                    if !isFocused && text != (cell.displayText ?? "") { onCommit(text) }
                }
        }
    }

    @ViewBuilder
    private var staticValue: some View {
        switch cell {
        case .null:
            Text("NULL").font(.jbMono(12)).italic().foregroundStyle(KTEditorTheme.faint)
        case let .int(intValue):
            Text(String(intValue)).font(.jbMono(12)).foregroundStyle(KTEditorTheme.Grid.number)
        case let .double(doubleValue):
            Text(String(doubleValue)).font(.jbMono(12)).foregroundStyle(KTEditorTheme.Grid.number)
        case let .bool(boolValue):
            Text(boolValue ? "true" : "false").font(.jbMono(12)).foregroundStyle(KTEditorTheme.label)
        case let .text(stringValue):
            Text(stringValue).font(.jbMono(12)).foregroundStyle(KTEditorTheme.label)
        case let .blob(dataValue):
            Text("[\(dataValue.count) bytes]").font(.jbMono(12)).italic().foregroundStyle(KTEditorTheme.faint)
        }
    }
}
