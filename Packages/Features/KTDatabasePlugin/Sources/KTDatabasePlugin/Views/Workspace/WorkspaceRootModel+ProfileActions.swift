import Foundation
import KTPlatformContracts
import KTPluginKit

extension WorkspaceRootModel {
    func profileContextActions(_ profile: ConnectionProfile) -> [SidebarAction] {
        var actions = [
            SidebarAction(title: "Backup…") { [weak self] in self?.backupProfile(profile) },
            SidebarAction(title: "Restore…") { [weak self] in self?.restoreProfile(profile) }
        ]
        if !profile.isManaged {
            actions.append(SidebarAction(title: "Sửa…") { [weak self] in self?.editSheet = profile })
            actions.append(SidebarAction(title: "Nhân bản") { [weak self] in self?.duplicate(profile) })
            actions.append(SidebarAction(title: "Xóa", isDestructive: true) { [weak self] in
                self?.connectionStore.remove(profile)
            })
        }
        return actions
    }

    func presentBackups() {
        guard let profile = selectedProfile else { return }
        Task { if await ensureBackupConnection(profile) { showBackups = true } }
    }

    func presentNewDatabase() {
        guard let profile = selectedProfile else { return }
        Task { if await ensureBackupConnection(profile) { sectionState.newDatabasePresented = true } }
    }

    private func backupProfile(_ profile: ConnectionProfile) {
        Task {
            guard await ensureBackupConnection(profile) else { return }
            let set = await databaseVM.backupAllDatabases(session: backupSession)
            if set != nil {
                feedback.toast("Backed up “\(profile.name)”")
            } else if case let .failed(message) = databaseVM.backupStatus {
                feedback.toast("Backup failed: \(message)")
            }
        }
    }

    private func restoreProfile(_ profile: ConnectionProfile) {
        Task { if await ensureBackupConnection(profile) { showBackups = true } }
    }

    private func ensureBackupConnection(_ profile: ConnectionProfile) async -> Bool {
        if databaseVM.selectedProfile?.id == profile.id, databaseVM.connection == .connected { return true }
        await databaseVM.select(profile: profile)
        if databaseVM.connection == .connected { return true }
        if case let .failed(error) = databaseVM.connection { feedback.toast(error.message) }
        return false
    }

    private func duplicate(_ profile: ConnectionProfile) {
        let copy = ConnectionProfile(
            name: "\(profile.name) copy",
            kind: profile.kind,
            host: profile.host,
            port: profile.port,
            user: profile.user,
            database: profile.database,
            filePath: profile.filePath,
            tlsMode: profile.tlsMode,
            readOnly: profile.readOnly
        )
        connectionStore.add(copy)
    }

    func recordRecent(_ table: TableInfo) {
        guard let pid = workspace.selectedProfileID, let db = workspace.activeDatabase else { return }
        workspace.recentStore.record(
            RecentObject(profileID: pid, database: db, name: table.name, isView: table.isView)
        )
    }

    func openRecent(_ object: RecentObject) {
        guard let profile = workspace.profiles.first(where: { $0.id == object.profileID }) else { return }
        workspace.selectedProfileID = profile.id
        Task {
            await connectStartingEngine(profile)
            guard isConnected else { return }
            if vm.selectedDatabase != object.database,
               vm.databases.contains(where: { $0.name == object.database }) {
                await vm.select(database: object.database)
                await refreshSchema(profileID: profile.id)
            }
            if let table = currentObjects.first(where: { $0.name == object.name }) {
                workspace.openTable(table, profileID: profile.id, database: object.database, forceNewTab: false)
            }
        }
    }
}
