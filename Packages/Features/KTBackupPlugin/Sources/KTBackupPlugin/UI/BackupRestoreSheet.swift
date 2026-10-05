import AppKit
import SwiftUI

struct BackupRestoreSheet: View {
    let plan: BackupPlan
    @ObservedObject var scheduler: BackupScheduler
    @ObservedObject var destinations: BackupDestinationsModel
    let services: BackupServices
    let onClose: () -> Void

    @State private var source: UUID?
    @State private var objects: [RemoteBackupObject] = []
    @State private var selection: RemoteBackupObject.ID?
    @State private var loading = false
    @State private var restoring: Double?
    @State private var error: String?
    @State private var result: BackupRestoreResult?

    init(plan: BackupPlan, scheduler: BackupScheduler, destinations: BackupDestinationsModel, services: BackupServices,
         onClose: @escaping () -> Void) {
        self.plan = plan
        self.scheduler = scheduler
        self.destinations = destinations
        self.services = services
        self.onClose = onClose
        _source = State(initialValue: scheduler.state.destination(plan.destinationID)?.id)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Restore \"\(plan.name)\"").font(.headline)
            Picker("From", selection: $source) {
                if let destination = scheduler.state.destination(plan.destinationID) {
                    Text(destination.name).tag(UUID?.some(destination.id))
                }
                Text("This Mac").tag(UUID?.none)
            }
            .disabled(restoring != nil)
            Table(objects, selection: $selection) {
                TableColumn("Backup", value: \.name)
                TableColumn("Created") { object in
                    Text(object.createdAt.map(BackupFormatting.dateTime) ?? "—")
                }
                .width(150)
                TableColumn("Size") { object in
                    Text(BackupFormatting.size(object.sizeBytes))
                }
                .width(80)
            }
            .overlay { emptyState }
            Text("Database dumps are added to Database › Backups, where you choose when to restore them into a server. "
                + "Site folders and settings are copied to a new folder in Downloads; nothing in place is overwritten.")
                .font(.caption).foregroundStyle(.secondary)
            outcome
            footer
        }
        .padding(16)
        .frame(width: 640, height: 520)
        .task(id: source) { await load() }
    }

    @ViewBuilder
    private var emptyState: some View {
        if loading {
            ProgressView()
        } else if objects.isEmpty, error == nil {
            Text("No backups from this plan here yet.").foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private var outcome: some View {
        if let error {
            Text(error).font(.caption).foregroundStyle(.red).textSelection(.enabled)
        } else if let result {
            VStack(alignment: .leading, spacing: 4) {
                if !result.importedDatabases.isEmpty {
                    Text("Added to Database › Backups: \(result.importedDatabases.joined(separator: ", "))").font(.caption)
                }
                ForEach(result.failedDatabases, id: \.self) { failure in
                    Text(failure).font(.caption).foregroundStyle(.red)
                }
                if let folder = result.extractedFolder {
                    Button("Show Restored Files in Finder") { NSWorkspace.shared.activateFileViewerSelecting([folder]) }
                        .buttonStyle(.link).font(.caption)
                }
            }
        }
    }

    private var footer: some View {
        HStack {
            if let restoring {
                ProgressView(value: restoring).frame(width: 160)
                Text("Downloading…").font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Button(result == nil ? "Cancel" : "Done", action: onClose).keyboardShortcut(.cancelAction).disabled(restoring != nil)
            Button("Restore", action: restore).keyboardShortcut(.defaultAction).disabled(selected == nil || restoring != nil)
        }
    }

    private var selected: RemoteBackupObject? {
        objects.first { $0.id == selection }
    }

    private func makeClient() throws -> any BackupDestinationClient {
        try services.factory.client(for: scheduler.state.destination(source))
    }

    private func load() async {
        loading = true
        error = nil
        defer { loading = false }
        do {
            objects = try await makeClient().list(ownedBy: plan.id).sorted { ($0.createdAt ?? .distantPast) > ($1.createdAt ?? .distantPast) }
            if selected == nil { selection = objects.first?.id }
        } catch {
            objects = []
            self.error = error.localizedDescription
        }
    }

    private func restore() {
        guard let object = selected else { return }
        let downloads = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first
            ?? FileManager.default.homeDirectoryForCurrentUser
        error = nil
        result = nil
        restoring = 0
        Task { @MainActor in
            defer { restoring = nil }
            do {
                let client = try makeClient()
                result = try await services.restorer(outputParent: downloads).restore(object, from: client) { fraction in
                    Task { @MainActor in if restoring != nil { restoring = fraction } }
                }
            } catch {
                self.error = error.localizedDescription
            }
        }
    }
}
