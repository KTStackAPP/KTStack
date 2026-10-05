import Foundation
import UserNotifications

struct BackupNotifier {
    func notifyFailure(planName: String, run: BackupRun) {
        guard run.status == .failed || run.status == .partial, run.trigger != .manual else { return }
        let center = UNUserNotificationCenter.current()
        center.requestAuthorization(options: [.alert, .sound]) { granted, _ in
            guard granted else { return }
            let content = UNMutableNotificationContent()
            content.title = run.status == .failed ? "Backup failed: \(planName)" : "Backup incomplete: \(planName)"
            content.body = run.message ?? "Open KTStack Settings → Scheduled Backups for details."
            content.sound = .default
            center.add(UNNotificationRequest(identifier: "ktstack.backup.\(run.id.uuidString)", content: content, trigger: nil))
        }
    }
}
