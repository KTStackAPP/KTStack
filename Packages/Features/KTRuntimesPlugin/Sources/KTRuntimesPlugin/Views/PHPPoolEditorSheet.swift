import KTPlatformContracts
import KTPluginKit
import SwiftUI

struct PHPPoolEditorSheet: View {
    let version: String
    @StateObject private var model: PHPPoolEditorModel
    @Environment(\.dismiss) private var dismiss

    init(version: String, phpConfig: any PHPPoolEditing) {
        self.version = version
        _model = StateObject(wrappedValue: PHPPoolEditorModel(version: version, phpConfig: phpConfig))
    }

    private var isDynamic: Bool { model.draft.processManager == .dynamic }
    private var isOnDemand: Bool { model.draft.processManager == .ondemand }

    var body: some View {
        VStack(alignment: .leading, spacing: KDSpacing.space3) {
            Text("PHP-FPM pool for PHP \(version)").font(KDFont.title)
            Text("Saving restarts PHP \(version)'s pool. Applies on next start if it is not running.")
                .font(KDFont.footnote).foregroundStyle(.secondary)

            Picker("Process manager", selection: $model.draft.processManager) {
                ForEach(PHPPoolProcessManager.allCases, id: \.self) { pm in
                    Text(pm.rawValue.capitalized).tag(pm)
                }
            }
            .pickerStyle(.segmented)
            .disabled(model.isSaving)

            VStack(alignment: .leading, spacing: KDSpacing.space2) {
                numberField("Max children", value: $model.draft.maxChildren, range: 1 ... 512)
                numberField("Start servers", value: $model.draft.startServers, range: 0 ... 512, enabled: isDynamic)
                numberField("Min spare servers", value: $model.draft.minSpareServers, range: 0 ... 512, enabled: isDynamic)
                numberField("Max spare servers", value: $model.draft.maxSpareServers, range: 0 ... 512, enabled: isDynamic)
                numberField("Idle timeout (s)", value: $model.draft.processIdleTimeout, range: 1 ... 3600, enabled: isOnDemand)
                numberField("Max requests", value: $model.draft.maxRequests, range: 0 ... 100_000)
                numberField("Request terminate timeout (s)", value: $model.draft.requestTerminateTimeout, range: 0 ... 3600)
            }

            if let message = model.error ?? model.validationMessage {
                Label(message, systemImage: "exclamationmark.triangle.fill")
                    .font(KDFont.footnote).foregroundStyle(Color.KDStatus.error)
                    .lineLimit(4)
            }

            HStack {
                Button("Reset to Default") { model.reset() }.disabled(model.isSaving)
                Spacer()
                Button("Cancel") { dismiss() }.keyboardShortcut(.cancelAction).disabled(model.isSaving)
                Button("Save", action: save)
                    .keyboardShortcut(.defaultAction)
                    .disabled(!model.canSave)
            }
        }
        .padding(KDSpacing.space4)
        .frame(width: 460)
        .onAppear { model.load() }
    }

    private func numberField(
        _ label: String,
        value: Binding<Int>,
        range: ClosedRange<Int>,
        enabled: Bool = true
    ) -> some View {
        HStack(spacing: KDSpacing.space2) {
            Text(label).font(KDFont.body).foregroundStyle(enabled ? .primary : .secondary)
            Spacer(minLength: 8)
            TextField("", value: value, format: .number)
                .textFieldStyle(.roundedBorder)
                .frame(width: 72)
                .multilineTextAlignment(.trailing)
            Stepper("", value: value, in: range).labelsHidden()
        }
        .disabled(!enabled || model.isSaving)
    }

    private func save() {
        Task {
            if await model.save() { dismiss() }
        }
    }
}
