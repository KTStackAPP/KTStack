import KTPlatformContracts
import SwiftUI

struct BackupPlanEditor: View {
    let isNew: Bool
    @ObservedObject var scheduler: BackupScheduler
    let environment: PlatformBackupEnvironment
    let databases: any ScheduledDatabaseBackupProviding
    let onClose: () -> Void

    @State var plan: BackupPlan
    @State private var error: String?
    private let original: BackupPlan

    init(plan: BackupPlan, isNew: Bool, scheduler: BackupScheduler, environment: PlatformBackupEnvironment,
         databases: any ScheduledDatabaseBackupProviding, onClose: @escaping () -> Void) {
        self.isNew = isNew
        self.scheduler = scheduler
        self.environment = environment
        self.databases = databases
        self.onClose = onClose
        original = plan
        _plan = State(initialValue: plan)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(isNew ? "New Backup Plan" : "Edit Backup Plan").font(.headline)
            Form {
                generalSection
                scheduleSection
                DatabaseSelectionSection(selection: $plan.databases, databases: databases)
                SiteSelectionSection(plan: $plan, sites: environment.sites)
                settingsSection
                destinationSection
            }
            .formStyle(.grouped)
            if let error {
                Text(error).font(.caption).foregroundStyle(.red)
            }
            HStack {
                Spacer()
                Button("Cancel", action: onClose).keyboardShortcut(.cancelAction)
                Button(isNew ? "Create Plan" : "Save", action: save).keyboardShortcut(.defaultAction)
            }
        }
        .padding(16)
        .frame(width: 620, height: 640)
    }

    private func save() {
        var result = plan
        result.name = result.name.trimmingCharacters(in: .whitespacesAndNewlines)
        result.siteExcludes = result.siteExcludes.map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        result.keepLast = max(1, result.keepLast)
        if result.destinationID == nil { result.keepLocalCopy = false }
        guard !result.name.isEmpty else {
            error = "Give the plan a name."
            return
        }
        guard !result.isEnabled || result.hasContent else {
            error = "Choose at least one database, a site folder or the KTStack settings, or turn the plan off."
            return
        }
        if !isNew, result.isEnabled, original.isEnabled, result.schedule != original.schedule {
            result.enabledAt = Date()
        }
        let saved = result
        do {
            try scheduler.update { state in
                if let index = state.plans.firstIndex(where: { $0.id == saved.id }) {
                    state.plans[index] = saved
                } else {
                    state.plans.append(saved)
                }
            }
            onClose()
        } catch {
            self.error = error.localizedDescription
        }
    }
}
