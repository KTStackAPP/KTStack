import SwiftUI
import KDWarmKit


struct AddConnectionSheet: View {
    @EnvironmentObject private var store: ConnectionStore
    @Environment(\.dismiss) private var dismiss

    let editing: ConnectionProfile?

    @State private var name = ""
    @State private var host = ""
    @State private var port = "3306"
    @State private var user = ""
    @State private var password = ""
    @State private var database = ""
    @State private var tlsMode: TLSMode = .verifyFull
    @State private var readOnly = true
    @State private var test: TestState = .idle

    enum TestState: Equatable {
        case idle, testing, ok
        case failed(String)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: KDSpacing.space3) {
            Text(editing == nil ? "Add Connection" : "Edit Connection").font(KDFont.headline)
            form
            testRow
            Divider()
            footer
        }
        .padding(KDSpacing.space4)
        .frame(width: 440)
        .onAppear(perform: hydrate)
    }

    private var form: some View {
        Form {
            TextField("Name", text: $name, prompt: Text("optional"))
            TextField("Host", text: $host, prompt: Text("db.example.com"))
            TextField("Port", text: $port)
            TextField("User", text: $user)
            SecureField("Password", text: $password,
                        prompt: Text(editing == nil ? "" : "leave blank to keep current"))
            TextField("Database", text: $database, prompt: Text("optional"))
            Picker("TLS", selection: $tlsMode) {
                ForEach(TLSMode.allCases, id: \.self) { Text($0.rawValue).tag($0) }
            }
            Toggle("Read-only (writes rejected by the server)", isOn: $readOnly)
        }
        .formStyle(.grouped)
        .onChange(of: host) { _ in test = .idle }
    }

    @ViewBuilder
    private var testRow: some View {
        HStack(spacing: KDSpacing.space2) {
            Button("Test Connection", action: runTest)
                .disabled(test == .testing || !isValid)
            switch test {
            case .idle: EmptyView()
            case .testing: ProgressView().controlSize(.small)
            case .ok:
                Label("Connected", systemImage: "checkmark.circle.fill")
                    .font(KDFont.footnote).foregroundStyle(.green)
            case .failed(let message):
                Label(message, systemImage: "exclamationmark.triangle.fill")
                    .font(KDFont.footnote).foregroundStyle(.orange).lineLimit(2)
            }
        }
    }

    private var footer: some View {
        HStack {
            Spacer()
            Button("Cancel") { dismiss() }.keyboardShortcut(.cancelAction)
            Button(editing == nil ? "Add" : "Save", action: save)
                .keyboardShortcut(.defaultAction).disabled(!isValid)
        }
    }

    private var isValid: Bool {
        !host.trimmingCharacters(in: .whitespaces).isEmpty
            && !user.trimmingCharacters(in: .whitespaces).isEmpty
            && (Int(port).map { (1...65535).contains($0) } ?? false)
    }

    private func hydrate() {
        guard let e = editing else { return }
        name = e.name; host = e.host; port = String(e.port)
        user = e.user; database = e.database
        tlsMode = e.tlsMode; readOnly = e.readOnly   // password intentionally left blank
    }

    private func buildProfile() -> ConnectionProfile? {
        let trimmedHost = host.trimmingCharacters(in: .whitespaces)
        guard isValid, let portNum = Int(port) else { return nil }
        return ConnectionProfile(
            id: editing?.id ?? UUID(),
            name: name.isEmpty ? trimmedHost : name,
            kind: .mysql,
            host: trimmedHost,
            port: portNum,
            user: user,
            database: database,
            tlsMode: tlsMode,
            readOnly: readOnly)
    }


    private var effectivePassword: String? {
        if !password.isEmpty { return password }
        guard let editing else { return nil }
        return try? KeychainStore().get(account: editing.id.uuidString)
    }


    private func runTest() {
        guard let profile = buildProfile() else { return }
        let pwd = effectivePassword
        test = .testing
        Task { @MainActor in
            let driver = MySQLDriver(profile: profile, password: pwd)
            do {
                try await driver.ping()
                test = .ok
            } catch {
                test = .failed((error as? DatabaseError)?.message ?? error.localizedDescription)
            }
        }
    }

    private func save() {
        guard let profile = buildProfile() else { return }
        let pwd = password.isEmpty ? nil : password
        if editing == nil {
            store.add(profile, password: pwd)
        } else {
            store.update(profile, password: pwd)   // nil pwd keeps the existing secret
        }
        dismiss()
    }
}
