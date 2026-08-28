import KTPluginKit
import SwiftUI

/// Create a view from a name and a SELECT body. The definition must start with SELECT; the dialect
/// enforces that and quotes the view name.
struct V2CreateViewSheet: View {
    @ObservedObject var vm: DatabaseV2ViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var definition = "SELECT "

    var body: some View {
        VStack(spacing: 0) {
            V2SheetHeader(title: "New View")
            VStack(alignment: .leading, spacing: 10) {
                TextField("view_name", text: $name).textFieldStyle(.roundedBorder).font(.jbMono(12.5))
                Text("Definition").font(.system(size: 12)).foregroundStyle(KTEditorTheme.label2)
                TextEditor(text: $definition)
                    .font(.jbMono(12.5))
                    .frame(minHeight: 160)
                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(KTEditorTheme.separator))
            }
            .padding(18)
            Divider().overlay(KTEditorTheme.separator)
            V2SheetFooter(confirmTitle: "Create View", confirmDisabled: !isValid, onCancel: { dismiss() }, onConfirm: submit)
        }
        .frame(width: 520, height: 420)
        .background(KTEditorTheme.content)
    }

    private var isValid: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty
            && definition.trimmingCharacters(in: .whitespaces).uppercased().hasPrefix("SELECT")
    }

    private func submit() {
        let viewName = name
        let body = definition
        dismiss()
        Task { await vm.createView(name: viewName, definition: body) }
    }
}
