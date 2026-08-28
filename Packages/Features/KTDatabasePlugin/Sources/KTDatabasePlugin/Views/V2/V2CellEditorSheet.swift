import KTPluginKit
import SwiftUI

struct V2CellEditorSheet: View {
    let context: V2CellEditorContext
    let onSave: (String) -> Void
    let onClose: () -> Void

    @State private var text: String
    @State private var jsonError: String?

    init(context: V2CellEditorContext, onSave: @escaping (String) -> Void, onClose: @escaping () -> Void) {
        self.context = context
        self.onSave = onSave
        self.onClose = onClose
        _text = State(initialValue: context.text)
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            editor
            if let jsonError {
                errorBanner(jsonError)
            }
            footer
        }
        .frame(width: 620, height: 460)
        .background(KTEditorTheme.window)
    }

    private var header: some View {
        HStack(spacing: 8) {
            Image(systemName: context.isBinary ? "doc.badge.ellipsis" : "curlybraces")
                .font(.system(size: 12))
                .foregroundStyle(KTEditorTheme.accent)
            Text(context.columnName)
                .font(.jbMono(13))
                .foregroundStyle(KTEditorTheme.label)
            if context.isBinary {
                Text("read-only")
                    .font(.jbMono(11))
                    .foregroundStyle(KTEditorTheme.label3)
            }
            Spacer()
            V2Button(title: "Close") { onClose() }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 11)
        .overlay(alignment: .bottom) { Divider().overlay(KTEditorTheme.separator) }
    }

    private var editor: some View {
        TextEditor(text: $text)
            .font(.jbMono(12.5))
            .foregroundStyle(KTEditorTheme.label)
            .scrollContentBackground(.hidden)
            .background(KTEditorTheme.content)
            .disabled(context.isBinary)
            .padding(8)
    }

    private func errorBanner(_ message: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.circle")
                .font(.system(size: 12))
                .foregroundStyle(KTEditorTheme.Status.error)
            Text(message)
                .font(.jbMono(12))
                .foregroundStyle(KTEditorTheme.Status.error)
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 7)
        .background(KTEditorTheme.Status.error.opacity(0.08))
    }

    private var footer: some View {
        HStack(spacing: 8) {
            Spacer()
            if !context.isBinary {
                V2Button(title: "Format") { format() }
                V2Button(title: "Save", kind: .primary) { save() }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 9)
        .overlay(alignment: .top) { Divider().overlay(KTEditorTheme.separator) }
    }

    private func format() {
        guard let pretty = prettyPrintedJSON(text) else {
            jsonError = "Invalid JSON"
            return
        }
        jsonError = nil
        text = pretty
    }

    private func save() {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty, prettyPrintedJSON(text) == nil {
            jsonError = "Invalid JSON"
            return
        }
        onSave(text)
    }

    private func prettyPrintedJSON(_ raw: String) -> String? {
        guard let data = raw.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed]),
              let pretty = try? JSONSerialization.data(withJSONObject: object, options: [.prettyPrinted, .sortedKeys, .fragmentsAllowed]),
              let string = String(data: pretty, encoding: .utf8) else { return nil }
        return string
    }
}
