import SwiftUI

extension BackupPlanEditor {
    var generalSection: some View {
        Section("General") {
            TextField("Name", text: $plan.name)
            Toggle("Run on schedule", isOn: enabledBinding)
        }
    }

    var scheduleSection: some View {
        Section {
            Picker("Repeat", selection: $plan.schedule.frequency) {
                Text("Every day").tag(BackupSchedule.Frequency.daily)
                Text("Every week").tag(BackupSchedule.Frequency.weekly)
            }
            if plan.schedule.frequency == .weekly {
                Picker("On", selection: $plan.schedule.weekday) {
                    ForEach(1...7, id: \.self) { day in
                        Text(BackupFormatting.weekdayName(day)).tag(day)
                    }
                }
            }
            DatePicker("At", selection: timeBinding, displayedComponents: .hourAndMinute)
            Stepper("Keep the last \(plan.keepLast) backups", value: $plan.keepLast, in: 1...365)
            Toggle("Skip while running on battery", isOn: $plan.skipOnBattery)
        } header: {
            Text("Schedule")
        } footer: {
            Text("If the Mac is asleep or KTStack is closed at that time, the backup runs once as soon as it can.")
        }
    }

    var settingsSection: some View {
        Section {
            Toggle("Include KTStack settings", isOn: $plan.includeSettings)
        } header: {
            Text("Settings")
        } footer: {
            Text("Site list, PHP and nginx configuration, shell tools, backup plans and app preferences. Secrets stay in the Keychain.")
        }
    }

    var destinationSection: some View {
        Section {
            Picker("Upload to", selection: $plan.destinationID) {
                Text("This Mac only").tag(UUID?.none)
                ForEach(scheduler.state.destinations) { destination in
                    Text("\(destination.name) (\(destination.kind.label))").tag(UUID?.some(destination.id))
                }
            }
            if plan.destinationID != nil {
                Toggle("Also keep a copy on this Mac", isOn: $plan.keepLocalCopy)
            }
        } header: {
            Text("Destination")
        } footer: {
            Text("Each plan uploads to one destination. Add S3 buckets, Google Drive or other folders under Backup Destinations.")
        }
    }

    private var enabledBinding: Binding<Bool> {
        Binding(get: { plan.isEnabled }, set: { plan.setEnabled($0, at: Date()) })
    }

    private var timeBinding: Binding<Date> {
        Binding(
            get: {
                Calendar.autoupdatingCurrent.date(
                    bySettingHour: plan.schedule.hour, minute: plan.schedule.minute, second: 0, of: Date()
                ) ?? Date()
            },
            set: { date in
                let parts = Calendar.autoupdatingCurrent.dateComponents([.hour, .minute], from: date)
                plan.schedule.hour = parts.hour ?? 0
                plan.schedule.minute = parts.minute ?? 0
            }
        )
    }
}
