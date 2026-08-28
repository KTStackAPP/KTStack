import KTPluginKit
import SwiftUI

/// Add a CHECK constraint. The expression is raw SQL (previewed); the renderer blocks statement
/// terminators and control characters only.
struct V2CheckConstraintSheet: View {
    @ObservedObject var vm: DatabaseV2ViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var expression = ""

    var body: some View {
        VStack(spacing: 0) {
            V2SheetHeader(title: "Add Check")
            VStack(alignment: .leading, spacing: 10) {
                TextField("constraint_name", text: $name).textFieldStyle(.roundedBorder).font(.jbMono(12.5))
                Text("Expression").font(.system(size: 12)).foregroundStyle(KTEditorTheme.label2)
                TextEditor(text: $expression)
                    .font(.jbMono(12.5))
                    .frame(minHeight: 120)
                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(KTEditorTheme.separator))
            }
            .padding(18)
            Divider().overlay(KTEditorTheme.separator)
            V2SheetFooter(confirmDisabled: !isValid, onCancel: { dismiss() }, onConfirm: submit)
        }
        .frame(width: 480, height: 340)
        .background(KTEditorTheme.content)
    }

    private var isValid: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty
            && !expression.trimmingCharacters(in: .whitespaces).isEmpty
    }

    private func submit() {
        let draft = CheckConstraintDraft(
            name: name.trimmingCharacters(in: .whitespaces),
            expression: expression.trimmingCharacters(in: .whitespaces)
        )
        dismiss()
        vm.previewChanges([.addCheck(draft)], title: "Add Check")
    }
}
