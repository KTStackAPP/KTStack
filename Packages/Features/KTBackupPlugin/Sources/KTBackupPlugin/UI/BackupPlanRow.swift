import KTPluginKit
import SwiftUI

struct BackupPlanRow: View {
    let plan: BackupPlan
    @ObservedObject var scheduler: BackupScheduler
    let onEdit: () -> Void
    let onRestore: () -> Void
    let onDelete: () -> Void

    var body: some View {
        KTSettingsRow(title: plan.name, subtitle: subtitle) {
            HStack(spacing: 8) {
                if let phase = scheduler.phases[plan.id] {
                    progress(phase)
                } else {
                    KTSettingsTextButton(title: "Back Up Now") { scheduler.runNow(plan.id) }
                }
                KTDropdown(width: 170, options: menuOptions) {
                    KTSettingsMenuValue(text: "More")
                }
                KTToggle("Enabled", isOn: plan.isEnabled, action: toggle)
            }
        }
    }

    private var subtitle: String {
        var lines = ["\(BackupFormatting.schedule(plan.schedule)) · \(BackupFormatting.contents(plan)) → "
            + BackupFormatting.destinationName(plan.destinationID, in: scheduler.state)]
        if let phase = scheduler.phases[plan.id] {
            lines.append(BackupFormatting.phase(phase))
        } else if let run = scheduler.state.lastRun(for: plan.id) {
            lines.append(BackupFormatting.status(run))
        }
        if plan.isEnabled, let next = scheduler.nextRun(for: plan) {
            lines.append("Next: \(BackupFormatting.dateTime(next))")
        } else if !plan.isEnabled {
            lines.append("Paused")
        }
        return lines.joined(separator: "\n")
    }

    private var menuOptions: [KTDropdownOption] {
        [
            KTDropdownOption(label: "Edit…", active: false, action: onEdit),
            KTDropdownOption(label: "Restore…", active: false, action: onRestore),
            KTDropdownOption(label: "Delete Plan…", active: false, action: onDelete)
        ]
    }

    private func progress(_ phase: BackupRunPhase) -> some View {
        HStack(spacing: 6) {
            if case let .uploading(fraction) = phase {
                ProgressView(value: fraction).frame(width: 80)
            } else {
                ProgressView().controlSize(.small)
            }
        }
    }

    private func toggle() {
        let now = Date()
        try? scheduler.update { state in
            guard let index = state.plans.firstIndex(where: { $0.id == plan.id }) else { return }
            state.plans[index].setEnabled(!state.plans[index].isEnabled, at: now)
        }
    }
}
