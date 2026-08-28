import KTPluginKit
import SwiftUI

/// Add an index to the selected table: name, member columns, unique flag.
struct V2IndexEditorSheet: View {
    @ObservedObject var vm: DatabaseV2ViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var columns: [String] = []
    @State private var isUnique = false

    var body: some View {
        VStack(spacing: 0) {
            V2SheetHeader(title: "Add Index")
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    TextField("index_name", text: $name).textFieldStyle(.roundedBorder).font(.jbMono(12.5))
                    Text("Columns").font(.system(size: 12)).foregroundStyle(KTEditorTheme.label2)
                    V2ColumnPicker(available: vm.columns.map(\.name), selected: $columns)
                    Toggle("Unique", isOn: $isUnique).toggleStyle(.checkbox).font(.system(size: 12))
                }
                .padding(18)
            }
            Divider().overlay(KTEditorTheme.separator)
            V2SheetFooter(confirmDisabled: !isValid, onCancel: { dismiss() }, onConfirm: submit)
        }
        .frame(width: 460, height: 400)
        .background(KTEditorTheme.content)
    }

    private var isValid: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty && !columns.isEmpty
    }

    private func submit() {
        let draft = IndexDraft(name: name.trimmingCharacters(in: .whitespaces), columns: columns, isUnique: isUnique)
        dismiss()
        vm.previewChanges([.addIndex(draft)], title: "Add Index")
    }
}
