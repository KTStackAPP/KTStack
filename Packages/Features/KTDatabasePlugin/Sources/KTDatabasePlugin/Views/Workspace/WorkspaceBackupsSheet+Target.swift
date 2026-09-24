import Foundation

extension WorkspaceBackupsSheet {
    var visibleSets: [BackupSet] {
        guard !showAllConnections, let profile = admin.selectedProfile else { return backupSets }
        return backupSets.filter { $0.belongs(to: profile) }
    }

    var targetName: String {
        guard let profile = admin.selectedProfile else { return "the connected server" }
        return "\(profile.name) (\(profile.host))"
    }

    func requestRestore(_ set: BackupSet) {
        guard let profile = admin.selectedProfile, let warning = set.targetWarning(for: profile) else {
            restoringSet = set
            return
        }
        feedback.confirm(
            title: "Restore into a different connection?",
            message: warning,
            okLabel: "Continue",
            danger: true
        ) {
            confirmedTargets.insert(set.id)
            restoringSet = set
        }
    }

    func reportFailure(unless succeeded: Bool) {
        guard !succeeded, case let .failed(message) = admin.backupStatus else { return }
        feedback.toast(message)
    }
}
