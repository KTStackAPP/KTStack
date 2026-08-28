import KTPluginKit
import SwiftUI

/// Add a foreign key to the selected table. Referenced columns are entered as a comma list because
/// the target table's columns aren't introspected here; referential actions are picked, not typed.
struct V2ForeignKeySheet: View {
    @ObservedObject var vm: DatabaseV2ViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var columns: [String] = []
    @State private var refTable = ""
    @State private var refColumnsText = ""
    @State private var onDelete: FKAction = .restrict
    @State private var onUpdate: FKAction = .restrict

    var body: some View {
        VStack(spacing: 0) {
            V2SheetHeader(title: "Add Foreign Key")
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    TextField("constraint_name", text: $name).textFieldStyle(.roundedBorder).font(.jbMono(12.5))
                    Text("Local columns").font(.system(size: 12)).foregroundStyle(KTEditorTheme.label2)
                    V2ColumnPicker(available: vm.columns.map(\.name), selected: $columns)
                    Picker("References table", selection: $refTable) {
                        Text("Select table").tag("")
                        ForEach(vm.tables.map(\.name), id: \.self) { Text($0).tag($0) }
                    }
                    .frame(maxWidth: 260, alignment: .leading)
                    TextField("referenced columns (comma separated)", text: $refColumnsText)
                        .textFieldStyle(.roundedBorder).font(.jbMono(12.5))
                    HStack(spacing: 14) {
                        actionPicker("ON DELETE", selection: $onDelete)
                        actionPicker("ON UPDATE", selection: $onUpdate)
                    }
                }
                .padding(18)
            }
            Divider().overlay(KTEditorTheme.separator)
            V2SheetFooter(confirmDisabled: !isValid, onCancel: { dismiss() }, onConfirm: submit)
        }
        .frame(width: 480, height: 460)
        .background(KTEditorTheme.content)
    }

    private func actionPicker(_ label: String, selection: Binding<FKAction>) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label).font(.system(size: 11)).foregroundStyle(KTEditorTheme.label3)
            Picker(label, selection: selection) {
                ForEach(FKAction.allCases, id: \.self) { Text($0.rawValue).tag($0) }
            }
            .labelsHidden()
            .frame(width: 150)
        }
    }

    private var refColumns: [String] {
        refColumnsText.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
    }

    private var isValid: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty && !columns.isEmpty
            && !refTable.isEmpty && !refColumns.isEmpty
    }

    private func submit() {
        let draft = ForeignKeyDraft(
            name: name.trimmingCharacters(in: .whitespaces),
            columns: columns,
            refTable: refTable,
            refColumns: refColumns,
            onDelete: onDelete,
            onUpdate: onUpdate
        )
        dismiss()
        vm.previewChanges([.addForeignKey(draft)], title: "Add Foreign Key")
    }
}
