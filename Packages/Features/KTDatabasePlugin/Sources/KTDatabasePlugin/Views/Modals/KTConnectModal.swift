import AppKit
import KTPluginKit
import SwiftUI
import UniformTypeIdentifiers

struct KTConnectModal: View {
    @EnvironmentObject private var store: ConnectionStore
    @EnvironmentObject private var vm: DatabaseViewModel
    @EnvironmentObject private var documentVM: DocumentViewModel
    let onClose: () -> Void
    let onConnected: (String) -> Void

    @State private var kind: DatabaseKind = .mysql
    @State private var name = ""
    @State private var host = "127.0.0.1"
    @State private var port = "3306"
    @State private var user = "root"
    @State private var password = ""
    @State private var database = ""
    @State private var filePath = ""
    @State private var tested = false
    @State private var testing = false
    @State private var testError: String?
    @State private var importingFile = false

    private var isValid: Bool {
        ConnectionProfileBuilder.isValid(kind: kind, host: host, port: port, user: user, filePath: filePath)
    }

    var body: some View {
        KTModalCard(
            icon: "cylinder.split.1x2",
            tint: KTIconTint.code,
            title: "Connect to Database",
            subtitle: "Choose an engine and enter your connection details.",
            width: 640,
            onClose: onClose
        ) {
            VStack(alignment: .leading, spacing: 0) {
                formBody
                KTConnectModalFooter(
                    testing: testing,
                    isValid: isValid,
                    tested: tested,
                    testError: testError,
                    onRunTest: runTest,
                    onClose: onClose,
                    onConnect: connect
                )
            }
            .onChange(of: fieldSignature) { _ in resetTest() }
            .fileImporter(isPresented: $importingFile, allowedContentTypes: [.data]) { result in
                if case let .success(url) = result {
                    filePath = url.path
                    if name.isEmpty { name = url.deletingPathExtension().lastPathComponent }
                    resetTest()
                }
            }
        }
    }

    private func createNewSQLiteFile() {
        let panel = NSSavePanel()
        panel.title = "New SQLite Database"
        panel.nameFieldStringValue = "database.sqlite"
        panel.allowedContentTypes = [UTType(filenameExtension: "sqlite") ?? .data]
        panel.canCreateDirectories = true
        guard panel.runModal() == .OK, let url = panel.url else { return }
        filePath = url.path
        if name.isEmpty { name = url.deletingPathExtension().lastPathComponent }
        resetTest()
    }

    private var formBody: some View {
        VStack(alignment: .leading, spacing: 14) {
            KTConnectEngineSelector(kind: $kind) { selected in
                port = ConnectionProfileBuilder.defaultPort(selected)
                user = ConnectionProfileBuilder.defaultUser(selected)
                password = ""
                resetTest()
            }
            KTModalLabeledRow(label: "Connection Name") {
                KTModalField(placeholder: "optional", text: $name)
            }
            if kind == .sqlite {
                sqliteFileRow
            } else {
                KTConnectServerFields(
                    kind: kind,
                    host: $host,
                    port: $port,
                    database: $database,
                    user: $user,
                    password: $password
                )
            }
        }
        .padding(.horizontal, 24).padding(.top, 22).padding(.bottom, 8)
    }

    private var sqliteFileRow: some View {
        VStack(alignment: .leading, spacing: 6) {
            KTModalLabeledRow(label: "Database File") {
                HStack(spacing: 8) {
                    KTModalField(placeholder: "/path/to/database.sqlite", text: $filePath, mono: true)
                    Button("Browse…") { importingFile = true }
                        .buttonStyle(.bordered)
                        .controlSize(.regular)
                    Button("New…") { createNewSQLiteFile() }
                        .buttonStyle(.bordered)
                        .controlSize(.regular)
                }
            }
            Text("Pick or create the .sqlite file with Browse…/New… so macOS grants access.")
                .font(.system(size: 11.5))
                .foregroundStyle(Color(nsColor: .secondaryLabelColor))
        }
    }

    private func runTest() {
        guard let profile = ConnectionProfileBuilder.build(
            kind: kind, name: name, host: host, port: port, user: user, database: database, filePath: filePath
        ) else { return }
        let pwd = password.isEmpty ? nil : password
        testing = true
        testError = nil
        tested = false
        Task { @MainActor in
            let tools = vm.tools
            let driver: DatabaseDriver? = profile.kind == .mongodb
                ? DocumentViewModel.defaultDriver(tools: tools)(profile, pwd)
                : DatabaseViewModel.defaultDriver(tools: tools)(profile, pwd)
            guard let driver else {
                testing = false
                testError = "Unsupported engine"
                return
            }
            do {
                try await driver.ping()
                testing = false
                tested = true
            } catch {
                testing = false
                testError = (error as? DatabaseError)?.message ?? error.localizedDescription
            }
        }
    }

    private func connect() {
        guard let profile = ConnectionProfileBuilder.build(
            kind: kind, name: name, host: host, port: port, user: user, database: database, filePath: filePath
        ) else { return }
        let pwd = password.isEmpty ? nil : password
        store.add(profile, password: pwd)
        testing = true
        testError = nil
        tested = false
        Task {
            if profile.kind == .mongodb {
                await documentVM.select(profile: profile)
                testing = false
                switch documentVM.connection {
                case .connected: onConnected(profile.name)
                case let .failed(error): testError = error.message
                default: testError = "Could not connect."
                }
            } else {
                await vm.select(profile: profile)
                testing = false
                switch vm.connection {
                case .connected: onConnected(profile.name)
                case let .failed(error): testError = error.message
                default: testError = "Could not connect."
                }
            }
        }
    }

    private func resetTest() {
        tested = false
        testError = nil
    }

    private var fieldSignature: String {
        "\(host)|\(port)|\(user)|\(password)|\(database)|\(filePath)"
    }
}
