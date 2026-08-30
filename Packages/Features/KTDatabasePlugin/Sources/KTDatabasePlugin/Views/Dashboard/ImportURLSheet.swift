import KTPluginKit
import SwiftUI

/// Nhập DSN rồi chuyển thẳng sang AddConnectionSheet trong cùng một sheet, tránh đóng/mở hai lần.
struct ImportURLSheet: View {
    @Environment(\.dismiss) private var dismiss

    @State private var text = ""
    @State private var error: String?
    @State private var draft: ConnectionDraft?

    var body: some View {
        if let draft {
            AddConnectionSheet(editing: nil, draft: draft)
        } else {
            form
        }
    }

    private var form: some View {
        VStack(alignment: .leading, spacing: KDSpacing.space3) {
            Text("Add from URL").font(KDFont.headline)
            TextField("mysql://user:password@127.0.0.1:3306/database", text: $text)
                .textFieldStyle(.roundedBorder)
                .onChange(of: text) { _ in error = nil }
            Text("Supports mysql://, postgres://, postgresql:// and mongodb:// URLs.")
                .font(.caption).foregroundStyle(.secondary)
            if let error {
                Label(error, systemImage: "exclamationmark.triangle.fill")
                    .font(KDFont.footnote).foregroundStyle(.orange)
            }
            Divider()
            HStack {
                Spacer()
                Button("Cancel") { dismiss() }.keyboardShortcut(.cancelAction)
                Button("Continue", action: parse)
                    .keyboardShortcut(.defaultAction)
                    .disabled(text.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding(KDSpacing.space4)
        .frame(width: 440)
    }

    private func parse() {
        do {
            draft = try ConnectionDSN.parse(text)
        } catch {
            self.error = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }
}
