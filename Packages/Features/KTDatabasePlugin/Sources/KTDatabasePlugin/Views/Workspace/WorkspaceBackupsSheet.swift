import AppKit
import KTPluginKit
import SwiftUI

struct WorkspaceBackupsSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var admin: DatabaseAdminModel
    let session: BackupSession
    @StateObject var feedback = KTFeedbackCenter()
    @State var backupSets: [BackupSet] = []
    @State var restoringSet: BackupSet?
    @State private var backingUp = false
    @State private var reloadGeneration = 0
    @State var showAllConnections = false
    @State var confirmedTargets: Set<UUID> = []

    private var isConnected: Bool { admin.connection == .connected }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider().overlay(KTColor.sepFaint)
            content
        }
        .frame(width: 560, height: 480)
        .background(KTColor.contentBg)
        .sheet(item: $restoringSet) { set in
            RestoreSheet(set: set, isReadOnly: admin.isReadOnlyConnection, targetName: targetName) { db, target in
                let restored = await admin.restoreBackup(
                    set, database: db, target: target, session: session,
                    confirmedTarget: confirmedTargets.contains(set.id)
                )
                reportFailure(unless: restored)
                await reloadBackups()
            }
        }
        .ktFeedbackHost(feedback)
        .task { await reloadBackups() }
    }

    private var header: some View {
        HStack(spacing: 10) {
            Text("Backups").font(KTType.screenTitle).tracking(KTType.screenTitleTracking).foregroundStyle(KTColor.ink)
            KTPill(text: "\(visibleSets.count)")
            Spacer()
            Toggle("All connections", isOn: $showAllConnections)
                .toggleStyle(.checkbox)
                .help("Also list backups made from other connections")
            KTButton(
                title: backingUp ? "Backing up…" : "Backup All Now",
                systemImage: "tray.and.arrow.down",
                kind: .primary,
                isLoading: backingUp
            ) { backupAll() }
                .disabled(!isConnected || backingUp)
            KTButton(title: "Close", kind: .secondary) { dismiss() }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
    }

    @ViewBuilder
    private var content: some View {
        if visibleSets.isEmpty {
            emptyState
        } else {
            ScrollView {
                KTListContainer {
                    VStack(spacing: 0) {
                        ForEach(Array(visibleSets.enumerated()), id: \.element.id) { index, set in
                            KTBackupRow(
                                backup: set,
                                onRestore: { requestRestore(set) },
                                onDownload: { download(set) },
                                onDelete: { confirmDelete(set) }
                            )
                            if index < visibleSets.count - 1 {
                                Rectangle().fill(KTColor.sepFaint).frame(height: 0.5).padding(.leading, 18)
                            }
                        }
                    }
                }
                .padding(20)
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "archivebox").font(.system(size: 42, weight: .light)).foregroundStyle(KTColor.faint)
            Text("No backups yet").font(.jbMono(16, .regular)).foregroundStyle(KTColor.ink3)
            Text("Run a backup to protect your databases.").font(.jbMono(12.5)).foregroundStyle(KTColor.muted)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func backupAll() {
        guard !backingUp else { return }
        backingUp = true
        Task {
            let set = await admin.backupAllDatabases(session: session)
            await reloadBackups()
            backingUp = false
            if set != nil { feedback.toast("Backup complete") } else { reportFailure(unless: false) }
        }
    }

    private func confirmDelete(_ set: BackupSet) {
        feedback.confirm(
            title: "Delete backup?",
            message: "Permanently delete this backup. This cannot be undone.",
            okLabel: "Delete",
            danger: true
        ) {
            admin.deleteBackup(set, session: session)
            Task { await reloadBackups() }
            feedback.toast("Backup deleted")
        }
    }

    private func download(_ set: BackupSet) {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "\(set.databases.first ?? "backup").zip"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        admin.exportBackup(set, to: url, session: session)
    }

    private func reloadBackups() async {
        let gen = reloadGeneration &+ 1
        reloadGeneration = gen
        let session = session
        let sets = await Task.detached { session.library.list() }.value
        guard gen == reloadGeneration else { return }
        backupSets = sets.sorted { $0.createdAt > $1.createdAt }
    }
}
