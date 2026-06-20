import SwiftUI
import KTStackKit

enum RowEditorMode: Identifiable {
    case insert
    case edit(Int)
    var id: String { if case .edit(let row) = self { return "edit-\(row)" } else { return "insert" } }
}

struct RowEditorView: View {
    @EnvironmentObject private var vm: DatabaseViewModel
    @Environment(\.dismiss) private var dismiss
    let mode: RowEditorMode

    @State private var fields: [String: Field] = [:]

    private struct Field { var text: String; var isNull: Bool }

    private var isInsert: Bool { if case .insert = mode { return true } else { return false } }
    private var title: String { isInsert ? "Add Row" : "Edit Row" }

    var body: some View {
        VStack(spacing: 0) {
            Text(title).font(KDFont.title).padding(KDSpacing.space3)
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: KDSpacing.space2) {
                    ForEach(vm.currentColumns) { column in fieldRow(column) }
                }
                .padding(KDSpacing.space3)
            }
            Divider()
            HStack {
                Spacer()
                Button("Cancel") { dismiss() }.keyboardShortcut(.cancelAction)
                Button("Save") { save() }.keyboardShortcut(.defaultAction).disabled(vm.isBusy)
            }
            .padding(KDSpacing.space3)
        }
        .frame(width: 420, height: 460)
        .onAppear(perform: loadFields)
    }

    @ViewBuilder
    private func fieldRow(_ column: ColumnInfo) -> some View {
        let readOnly = !isInsert && column.isPrimaryKey
        let binding = fieldBinding(column.name)
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: KDSpacing.space2) {
                Text(column.name).font(KDFont.body)
                if column.isPrimaryKey {
                    Text("PK").font(KDFont.footnote).foregroundStyle(.tertiary)
                }
                Spacer()
                Text(column.dataType).font(KDFont.footnote).foregroundStyle(.tertiary)
            }
            HStack(spacing: KDSpacing.space2) {
                TextField("", text: binding.text)
                    .textFieldStyle(.roundedBorder).font(KDFont.mono)
                    .disabled(readOnly || binding.wrappedValue.isNull)
                if column.isNullable && !readOnly {
                    Toggle("NULL", isOn: binding.isNull).toggleStyle(.checkbox)
                        .font(KDFont.footnote)
                }
            }
        }
    }

    // MARK: - State

    private func loadFields() {
        var initial: [String: Field] = [:]
        let row = currentRowCells
        for (index, column) in vm.currentColumns.enumerated() {
            let cell = row?[safe: index]
            initial[column.name] = Field(text: cell?.displayText ?? "",
                                         isNull: cell.map { $0 == .null } ?? false)
        }
        fields = initial
    }


    private var currentRowCells: [Cell]? {
        guard case .edit(let rowIndex) = mode,
              let result = vm.result, rowIndex < result.rows.count else { return nil }
        return result.rows[rowIndex]
    }

    private func fieldBinding(_ name: String) -> Binding<Field> {
        Binding(
            get: { fields[name] ?? Field(text: "", isNull: false) },
            set: { fields[name] = $0 })
    }

    private func save() {
        let values = buildValues()
        Task {
            switch mode {
            case .insert:        await vm.insertRow(values)
            case .edit(let row): await vm.updateRow(at: row, values: values)
            }
            dismiss()   // errors surface via the section's edit-error alert after the sheet closes
        }
    }

  
    private func buildValues() -> [ColumnValue] {
        var out: [ColumnValue] = []
        for column in vm.currentColumns {
            if !isInsert && column.isPrimaryKey { continue }
            let field = fields[column.name] ?? Field(text: "", isNull: false)
            if field.isNull {
                out.append(ColumnValue(column: column.name, value: .null))
            } else if isInsert && field.text.isEmpty && (column.defaultValue != nil || column.isNullable) {
                continue
            } else {
                out.append(ColumnValue(column: column.name, value: .text(field.text)))
            }
        }
        return out
    }
}

private extension Array {

    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
