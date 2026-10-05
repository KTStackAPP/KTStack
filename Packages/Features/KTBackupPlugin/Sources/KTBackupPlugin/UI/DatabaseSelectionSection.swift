import KTPlatformContracts
import SwiftUI

struct DatabaseSelectionSection: View {
    @Binding var selection: [BackupDatabaseSelection]
    let databases: any ScheduledDatabaseBackupProviding

    @State private var engines: [DatabaseEngine] = []
    @State private var available: [DatabaseEngine: [String]] = [:]
    @State private var failures: [DatabaseEngine: String] = [:]
    @State private var loaded = false
    @State private var started = false

    var body: some View {
        Section {
            if !loaded {
                ProgressView().controlSize(.small)
            } else if engines.isEmpty {
                Text("No database engines are installed.").foregroundStyle(.secondary)
            }
            ForEach(engines, id: \.self) { engine in
                engineRows(engine)
            }
            ForEach(missing, id: \.self) { item in
                Toggle("\(Self.label(item.engine)) · \(item.database) (not found)", isOn: binding(item))
            }
        } header: {
            HStack {
                Text("Databases")
                Spacer()
                Button("Refresh") { Task { await load() } }.buttonStyle(.link).disabled(!loaded)
            }
        } footer: {
            Text("Databases are dumped with the engine's own tools. An engine that isn't running when the plan starts is skipped and reported.")
        }
        .task {
            guard !started else { return }
            started = true
            await load()
        }
    }

    @ViewBuilder
    private func engineRows(_ engine: DatabaseEngine) -> some View {
        let names = available[engine] ?? []
        if let failure = failures[engine] {
            LabeledContent(Self.label(engine.rawValue)) {
                Text(failure).foregroundStyle(.secondary).multilineTextAlignment(.trailing)
            }
        } else if names.isEmpty {
            LabeledContent(Self.label(engine.rawValue)) {
                Text("No user databases").foregroundStyle(.secondary)
            }
        } else {
            ForEach(names, id: \.self) { name in
                Toggle("\(Self.label(engine.rawValue)) · \(name)",
                       isOn: binding(BackupDatabaseSelection(engine: engine.rawValue, database: name)))
            }
        }
    }

    private var missing: [BackupDatabaseSelection] {
        guard loaded else { return [] }
        return selection.filter { item in
            guard let engine = DatabaseEngine(rawValue: item.engine), failures[engine] == nil else { return false }
            return !(available[engine] ?? []).contains(item.database)
        }
    }

    private func binding(_ item: BackupDatabaseSelection) -> Binding<Bool> {
        Binding(
            get: { selection.contains(item) },
            set: { isOn in
                if isOn {
                    if !selection.contains(item) { selection.append(item) }
                } else {
                    selection.removeAll { $0 == item }
                }
            }
        )
    }

    private func load() async {
        loaded = false
        let installed = databases.installedEngines()
        var names: [DatabaseEngine: [String]] = [:]
        var errors: [DatabaseEngine: String] = [:]
        for engine in installed {
            do {
                names[engine] = try await databases.userDatabases(engine).sorted()
            } catch {
                errors[engine] = "Start \(Self.label(engine.rawValue)) to list its databases."
            }
        }
        engines = installed
        available = names
        failures = errors
        loaded = true
    }

    static func label(_ engine: String) -> String {
        switch engine {
        case DatabaseEngine.mysql.rawValue: "MySQL"
        case DatabaseEngine.postgres.rawValue: "PostgreSQL"
        case DatabaseEngine.mongodb.rawValue: "MongoDB"
        default: engine
        }
    }
}
