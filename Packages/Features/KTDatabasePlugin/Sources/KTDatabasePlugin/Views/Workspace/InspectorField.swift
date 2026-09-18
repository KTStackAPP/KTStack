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
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .foregroundStyle(KTEditorTheme.label2)
                if isPrimaryKey {
                    Text("PK")
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background(Color.accentColor.opacity(0.15), in: RoundedRectangle(cornerRadius: 3))
                        .foregroundStyle(Color.accentColor)
                }
                if isForeignKey {
                    Text("FK")
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background(Color.blue.opacity(0.15), in: RoundedRectangle(cornerRadius: 3))
                        .foregroundStyle(Color.blue)
                }
                Text(dataType)
                    .font(.system(size: 10, design: .monospaced))
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
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
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
                .font(.system(size: 11.5, design: .monospaced))
                .frame(height: 70)
                .padding(4)
                .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 5))
                .overlay(
                    RoundedRectangle(cornerRadius: 5)
                        .stroke(focused ? Color.accentColor : Color(nsColor: .separatorColor).opacity(0.6), lineWidth: focused ? 1.5 : 0.5)
                )
                .focused($focused)
                .onChange(of: focused) { isFocused in
                    if !isFocused && text != (cell.displayText ?? "") { onCommit(text) }
                }
        } else {
            TextField("", text: $text)
                .textFieldStyle(.plain)
                .font(.system(size: 12, design: .monospaced))
                .padding(.horizontal, 6)
                .padding(.vertical, 4)
                .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 5))
                .overlay(
                    RoundedRectangle(cornerRadius: 5)
                        .stroke(focused ? Color.accentColor : Color(nsColor: .separatorColor).opacity(0.6), lineWidth: focused ? 1.5 : 0.5)
                )
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
            Text("NULL").font(.system(size: 12, design: .monospaced)).italic().foregroundStyle(KTEditorTheme.faint)
        case let .int(intValue):
            Text(String(intValue)).font(.system(size: 12, design: .monospaced)).foregroundStyle(KTEditorTheme.Grid.number)
        case let .double(doubleValue):
            Text(String(doubleValue)).font(.system(size: 12, design: .monospaced)).foregroundStyle(KTEditorTheme.Grid.number)
        case let .bool(boolValue):
            Text(boolValue ? "true" : "false").font(.system(size: 12, design: .monospaced)).foregroundStyle(KTEditorTheme.label)
        case let .text(stringValue):
            Text(stringValue).font(.system(size: 12, design: .monospaced)).foregroundStyle(KTEditorTheme.label)
        case let .blob(dataValue):
            Text("[\(dataValue.count) bytes]").font(.system(size: 12, design: .monospaced)).italic().foregroundStyle(KTEditorTheme.faint)
        }
    }
}
