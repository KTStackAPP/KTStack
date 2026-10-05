import SwiftUI

struct DestinationEditor: View {
    @ObservedObject var model: BackupDestinationsModel
    let isNew: Bool
    let onClose: () -> Void

    @State var destination: BackupDestination
    @State var s3Secret = ""
    @State var googleClientSecret = ""
    @State var googleConnected = false
    @State var browsing: FolderBrowsing?
    @State var busy = false
    @State var error: String?
    @State private var testResult: DestinationTestResult?

    init(draft: DestinationDraft, model: BackupDestinationsModel, onClose: @escaping () -> Void) {
        self.model = model
        isNew = draft.isNew
        self.onClose = onClose
        _destination = State(initialValue: draft.destination)
        _testResult = State(initialValue: draft.destination.lastTest)
        _googleConnected = State(initialValue: model.hasSecret(.googleRefreshToken, for: draft.destination.id))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(isNew ? "Add \(destination.kind.label)" : "Edit \(destination.name)").font(.headline)
            Form {
                Section {
                    TextField("Name", text: $destination.name)
                }
                switch destination.kind {
                case .local: localSections
                case .s3: s3Sections
                case .googleDrive: googleSections
                }
            }
            .formStyle(.grouped)
            status
            footer
        }
        .padding(16)
        .frame(width: 560, height: 600)
        .sheet(item: $browsing) { browsing in
            browserSheet(browsing)
        }
    }

    @ViewBuilder
    private var status: some View {
        if let error {
            Text(error).font(.caption).foregroundStyle(.red).textSelection(.enabled)
        } else if let testResult {
            Label(testResult.message, systemImage: testResult.succeeded ? "checkmark.circle.fill" : "xmark.octagon.fill")
                .font(.caption)
                .foregroundStyle(testResult.succeeded ? Color.green : Color.red)
                .textSelection(.enabled)
        }
    }

    private var footer: some View {
        HStack {
            Button("Test Connection", action: test).disabled(busy)
            if busy { ProgressView().controlSize(.small) }
            Spacer()
            Button("Cancel", action: cancel).keyboardShortcut(.cancelAction)
            Button(isNew ? "Add Destination" : "Save", action: save).keyboardShortcut(.defaultAction).disabled(busy)
        }
    }

    var pendingSecrets: [BackupSecretKind: String] {
        var secrets: [BackupSecretKind: String] = [:]
        if destination.kind == .s3, !s3Secret.isEmpty { secrets[.s3SecretAccessKey] = s3Secret }
        if destination.kind == .googleDrive {
            if (destination.googleDrive?.customClientID ?? "").isEmpty {
                secrets[.googleClientSecret] = ""
            } else if !googleClientSecret.isEmpty {
                secrets[.googleClientSecret] = googleClientSecret
            }
        }
        return secrets
    }

    func draftClient() throws -> any BackupDestinationClient {
        try model.client(for: destination, secrets: pendingSecrets.filter { !$0.value.isEmpty })
    }

    func run(_ work: @escaping @MainActor () async throws -> Void) {
        busy = true
        error = nil
        Task { @MainActor in
            defer { busy = false }
            do {
                try await work()
            } catch {
                self.error = error.localizedDescription
            }
        }
    }

    private func test() {
        guard validationMessage == nil else {
            error = validationMessage
            return
        }
        run {
            let result = await model.test(destination, secrets: pendingSecrets.filter { !$0.value.isEmpty })
            testResult = result
            destination.lastTest = result
        }
    }

    private func save() {
        destination.name = destination.name.trimmingCharacters(in: .whitespacesAndNewlines)
        if let message = validationMessage {
            error = message
            return
        }
        do {
            try model.save(destination, secrets: pendingSecrets)
            onClose()
        } catch {
            self.error = error.localizedDescription
        }
    }

    private func cancel() {
        if isNew { model.discardDraft(destination.id) }
        onClose()
    }
}
