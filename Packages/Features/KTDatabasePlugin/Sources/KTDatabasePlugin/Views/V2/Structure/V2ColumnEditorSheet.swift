import KTPluginKit
import SwiftUI

/// Add or edit one column on the selected table. Edit seeds from the faithful server draft so an
/// unrelated change can't drop the column's comment, charset, default or ON UPDATE.
struct V2ColumnEditorSheet: View {
    @ObservedObject var vm: DatabaseV2ViewModel
    @Environment(\.dismiss) private var dismiss
    let original: ColumnInfo?

    @State private var state = ColumnFormState()

    private var isEdit: Bool { original != nil }

    var body: some View {
        VStack(spacing: 0) {
            V2SheetHeader(title: isEdit ? "Edit Column" : "Add Column")
            ScrollView {
                ColumnFormView(state: $state)
                    .padding(18)
            }
            Divider().overlay(KTEditorTheme.separator)
            V2SheetFooter(
                confirmTitle: "Preview SQL",
                confirmDisabled: !state.isValid,
                onCancel: { dismiss() },
                onConfirm: submit
            )
        }
        .frame(width: 520, height: 460)
        .background(KTEditorTheme.content)
        .onAppear {
            if let original {
                state = ColumnFormState(SchemaEditDraft.draft(from: original))
            }
        }
    }

    private func submit() {
        let draft = state.toDraft()
        let change: SchemaChange = isEdit
            ? .modifyColumn(original: original?.name ?? draft.name, draft)
            : .addColumn(draft, after: nil)
        dismiss()
        vm.previewChanges([change], title: isEdit ? "Edit Column" : "Add Column")
    }
}
