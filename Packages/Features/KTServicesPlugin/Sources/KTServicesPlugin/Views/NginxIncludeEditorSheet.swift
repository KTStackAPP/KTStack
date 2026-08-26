import KTPluginKit
import SwiftUI

struct NginxIncludeEditorSheet: View {
    @ObservedObject var model: NginxIncludeEditorModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: KDSpacing.space3) {
            Text("Edit nginx config").font(KDFont.title)
            Text("Changes are validated with nginx -t and reloaded. A .bak is kept for revert.")
                .font(KDFont.footnote).foregroundStyle(.secondary)

            TextEditor(text: $model.text)
                .font(KDFont.mono)
                .frame(minWidth: 560, minHeight: 360)
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(.separator, lineWidth: 0.5))
                .disabled(model.isBusy)

            if let msg = model.errorMessage {
                ScrollView {
                    Text(msg)
                        .font(KDFont.footnote).foregroundStyle(Color.KDStatus.error)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(maxHeight: 120)
            }

            HStack {
                Button("Reset to Default") { model.reset() }.disabled(model.isBusy)
                Spacer()
                Button("Cancel") { dismiss() }.keyboardShortcut(.cancelAction).disabled(model.isBusy)
                Button(model.isBusy ? "Saving…" : "Save") {
                    Task { if await model.save() { dismiss() } }
                }
                .keyboardShortcut(.defaultAction)
                .disabled(model.isBusy || model.text.isEmpty)
            }
        }
        .padding(KDSpacing.space4)
        .frame(width: 640)
        .onAppear { model.load() }
    }
}
