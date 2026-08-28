import KTPluginKit
import SwiftUI

/// Full create-table flow: typed columns with per-column primary-key selection plus basic table
/// options, rendered to one CREATE TABLE statement through the shared preview.
struct V2CreateTableSheet: View {
    @ObservedObject var vm: DatabaseV2ViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var tableName = ""
    @State private var columns: [ColumnFormState] = [ColumnFormState()]
    @State private var engine = ""
    @State private var charset = ""

    var body: some View {
        VStack(spacing: 0) {
            V2SheetHeader(title: "New Table")
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    TextField("table_name", text: $tableName)
                        .textFieldStyle(.roundedBorder)
                        .font(.jbMono(13))
                    ForEach($columns) { $column in
                        columnCard($column)
                    }
                    Button {
                        columns.append(ColumnFormState())
                    } label: {
                        Label("Add column", systemImage: "plus")
                            .font(.system(size: 12.5))
                            .foregroundStyle(KTEditorTheme.accent)
                    }
                    .buttonStyle(.plain)
                    optionsRow
                }
                .padding(18)
            }
            Divider().overlay(KTEditorTheme.separator)
            V2SheetFooter(confirmDisabled: !isValid, onCancel: { dismiss() }, onConfirm: submit)
        }
        .frame(width: 560, height: 560)
        .background(KTEditorTheme.content)
    }

    private func columnCard(_ column: Binding<ColumnFormState>) -> some View {
        VStack(spacing: 8) {
            ColumnFormView(state: column, showPrimaryKeyToggle: true)
            if columns.count > 1 {
                HStack {
                    Spacer()
                    Button(role: .destructive) {
                        columns.removeAll { $0.id == column.wrappedValue.id }
                    } label: {
                        Image(systemName: "minus.circle").foregroundStyle(KTEditorTheme.Status.error)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(10)
        .background(KTEditorTheme.content2, in: RoundedRectangle(cornerRadius: 6))
    }

    private var optionsRow: some View {
        HStack(spacing: 8) {
            TextField("engine (optional)", text: $engine).textFieldStyle(.roundedBorder).font(.jbMono(12.5))
            TextField("charset (optional)", text: $charset).textFieldStyle(.roundedBorder).font(.jbMono(12.5))
        }
    }

    private var isValid: Bool {
        !tableName.trimmingCharacters(in: .whitespaces).isEmpty && columns.allSatisfy(\.isValid)
    }

    private func submit() {
        let draft = TableDefinitionDraft(
            name: tableName.trimmingCharacters(in: .whitespaces),
            columns: columns.map { $0.toDraft() },
            primaryKey: columns.filter(\.isPrimaryKey).map(\.trimmedName),
            options: TableOptionDraft(
                engine: engine.isEmpty ? nil : engine,
                charset: charset.isEmpty ? nil : charset
            )
        )
        dismiss()
        vm.previewCreateTable(draft)
    }
}
