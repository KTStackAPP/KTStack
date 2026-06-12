import SwiftUI
import KDWarmKit

/// Edit one PHP version's managed `php.ini` (the Laragon "Edit php.ini" affordance, scoped per
/// installed version). Save rewrites the file (keeping a `.bak`) and reloads only that version's
/// php-fpm pool; if the reload fails the user can revert to the backup. Reset restores the template.
struct PHPIniEditorSheet: View {
    let version: String
    @EnvironmentObject private var server: LocalServerController
    @Environment(\.dismiss) private var dismiss

    @State private var text = ""
    @State private var error: String?
    @State private var isSaving = false

    private let store = PHPIniStore()

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
        do { text = try store.read(version: version); error = nil }
        catch { self.error = error.localizedDescription }
    }

    private func save() {
        error = nil
        isSaving = true
        let candidate = text
        let store = self.store
        let version = self.version
        Task {
            // Parse-check before touching the live file so a broken ini never reaches the pool.
            if let problem = await Task.detached(priority: .userInitiated, operation: {
                store.validate(version: version, contents: candidate)
            }).value {
                self.error = "php.ini has a syntax error (not applied):\n\(problem)"
                self.isSaving = false
                return
            }
            do {
                try store.write(version: version, contents: candidate)   // atomic + .bak
            } catch {
                self.error = error.localizedDescription
                self.isSaving = false
                return
            }
            do {
                try await server.reloadPHPPool(version: version)
                isSaving = false
                dismiss()
            } catch {
                // Reload failed — roll the live file back to the last good content and reload again so
                // the pool comes back up rather than crash-looping on the rejected ini.
                _ = try? store.restoreBackup(version: version)
                try? await server.reloadPHPPool(version: version)
                self.error = "Reload failed; reverted to the previous php.ini.\n\(error.localizedDescription)"
                self.isSaving = false
            }
        }
    }

    private func reset() {
        // Restore the template into the editor; the user still has to Save to apply + reload it.
        text = PHPIniTemplate.default
        error = nil
    }
}
