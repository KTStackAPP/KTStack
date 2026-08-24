import KTPlatformContracts
import KTPluginKit
import SwiftUI

struct PHPIniEditorSheet: View {
    let version: String
    let phpConfig: any PHPIniEditing
    @Environment(\.dismiss) private var dismiss

    @State private var text = ""
    @State private var error: String?
    @State private var isSaving = false

    var body: some View {
        VStack(alignment: .leading, spacing: KDSpacing.space3) {
            Text("Edit php.ini — PHP \(version)").font(KDFont.title)
            Text("Saved changes reload PHP \(version) only. A .bak is kept for revert.")
                .font(KDFont.footnote).foregroundStyle(.secondary)

            TextEditor(text: $text)
                .font(KDFont.mono)
                .frame(minWidth: 560, minHeight: 360)
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(.separator, lineWidth: 0.5))
                .disabled(isSaving)

            if let error {
                Label(error, systemImage: "exclamationmark.triangle.fill")
                    .font(KDFont.footnote).foregroundStyle(Color.KDStatus.error)
                    .lineLimit(3)
            }

            HStack {
                Button("Reset to Default", action: reset).disabled(isSaving)
                Spacer()
                Button("Cancel") { dismiss() }.keyboardShortcut(.cancelAction).disabled(isSaving)
                Button("Save", action: save)
                    .keyboardShortcut(.defaultAction)
                    .disabled(isSaving || text.isEmpty)
            }
        }
        .padding(KDSpacing.space4)
        .frame(width: 640)
        .onAppear(perform: load)
    }

    private func load() {
        do { text = try phpConfig.readIni(phpVersion: version); error = nil }
        catch { self.error = error.localizedDescription }
    }

    private func save() {
        error = nil
        isSaving = true
        let candidate = text
        let phpConfig = phpConfig
        let version = version
        Task {
            do {
                try await phpConfig.saveIni(phpVersion: version, contents: candidate)
                isSaving = false
                dismiss()
            } catch let error as PHPIniSaveError {
                switch error {
                case let .syntax(problem):
                    self.error = "php.ini has a syntax error (not applied):\n\(problem)"
                case let .reloadFailedReverted(detail):
                    self.error = "Reload failed; reverted to the previous php.ini.\n\(detail)"
                }
                isSaving = false
            } catch {
                self.error = error.localizedDescription
                isSaving = false
            }
        }
    }

    private func reset() {
        text = phpConfig.defaultTemplate
        error = nil
    }
}
