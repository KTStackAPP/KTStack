import KTPluginKit
import SwiftUI

/// Edit table-level options (engine, charset, collation, auto-increment, comment) on the selected
/// table. Only non-empty fields are applied.
struct V2TableOptionsSheet: View {
    @ObservedObject var vm: DatabaseV2ViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var engine = ""
    @State private var charset = ""
    @State private var collation = ""
    @State private var autoIncrement = ""
    @State private var comment = ""

    var body: some View {
        VStack(spacing: 0) {
            V2SheetHeader(title: "Table Options")
            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    field("engine (optional)", text: $engine)
                    field("charset (optional)", text: $charset)
                    field("collation (optional)", text: $collation)
                    field("auto_increment (optional)", text: $autoIncrement)
                    field("comment (optional)", text: $comment)
                }
                .padding(18)
            }
            Divider().overlay(KTEditorTheme.separator)
            V2SheetFooter(confirmDisabled: !isValid, onCancel: { dismiss() }, onConfirm: submit)
        }
        .frame(width: 460, height: 380)
        .background(KTEditorTheme.content)
    }

    private func field(_ placeholder: String, text: Binding<String>) -> some View {
        TextField(placeholder, text: text).textFieldStyle(.roundedBorder).font(.jbMono(12.5))
    }

    private var option: TableOptionDraft {
        TableOptionDraft(
            engine: engine.isEmpty ? nil : engine,
            charset: charset.isEmpty ? nil : charset,
            collation: collation.isEmpty ? nil : collation,
            autoIncrement: Int64(autoIncrement.trimmingCharacters(in: .whitespaces)),
            comment: comment.isEmpty ? nil : comment
        )
    }

    private var isValid: Bool { !option.isEmpty }

    private func submit() {
        dismiss()
        vm.previewChanges([.setTableOptions(option)], title: "Table Options")
    }
}
