import AppKit
import KTPluginKit
import SwiftUI

struct DestinationDraft: Identifiable {
    var destination: BackupDestination
    var isNew: Bool

    var id: UUID {
        destination.id
    }
}

struct BackupSettingsPane: View {
    @ObservedObject var scheduler: BackupScheduler
    @ObservedObject var destinations: BackupDestinationsModel
    let environment: PlatformBackupEnvironment
    let services: BackupServices

    @State private var editingPlan: BackupPlan?
    @State private var editingDestination: DestinationDraft?
    @State private var restoringPlan: BackupPlan?
    @State private var removingDestination: BackupDestination?
    @State private var deletingPlan: BackupPlan?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            plansGroup
            destinationsGroup
        }
        .sheet(item: $editingPlan) { plan in
            BackupPlanEditor(plan: plan, isNew: scheduler.state.plan(plan.id) == nil, scheduler: scheduler,
                             environment: environment, databases: services.databases) { editingPlan = nil }
        }
        .sheet(item: $editingDestination) { draft in
            DestinationEditor(draft: draft, model: destinations) { editingDestination = nil }
        }
        .sheet(item: $restoringPlan) { plan in
            BackupRestoreSheet(plan: plan, scheduler: scheduler, destinations: destinations, services: services) { restoringPlan = nil }
        }
        .confirmationDialog(removalTitle, isPresented: removalBinding, presenting: removingDestination) { destination in
            removalButtons(destination)
        } message: { destination in
            Text(removalMessage(destination))
        }
        .confirmationDialog("Delete plan \"\(deletingPlan?.name ?? "")\"?", isPresented: deletionBinding, presenting: deletingPlan) { plan in
            Button("Delete Plan", role: .destructive) { try? scheduler.update { state in state.plans.removeAll { $0.id == plan.id } } }
            Button("Cancel", role: .cancel) {}
        } message: { _ in
            Text("Backups already uploaded stay where they are.")
        }
    }

    private var plansGroup: some View {
        KTSettingsGroup(title: "Scheduled Backups") {
            ForEach(scheduler.state.plans) { plan in
                BackupPlanRow(
                    plan: plan, scheduler: scheduler,
                    onEdit: { editingPlan = plan },
                    onRestore: { restoringPlan = plan },
                    onDelete: { deletingPlan = plan }
                )
            }
            KTSettingsRow(
                title: scheduler.state.plans.isEmpty ? "No backup plans yet" : "New plan",
                subtitle: "Back up databases, site folders and KTStack settings on a schedule.",
                showDivider: false
            ) {
                KTSettingsTextButton(title: "Add Plan…") {
                    editingPlan = BackupPlan(name: "Nightly backup", isEnabled: true, enabledAt: Date())
                }
            }
        }
    }

    private var destinationsGroup: some View {
        KTSettingsGroup(title: "Backup Destinations") {
            KTSettingsRow(title: "This Mac", subtitle: services.paths.archives.path) {
                KTSettingsTextButton(title: "Show in Finder") { NSWorkspace.shared.open(services.paths.archives) }
            }
            ForEach(destinations.destinations) { destination in
                BackupDestinationRow(
                    destination: destination, model: destinations,
                    onEdit: { editingDestination = DestinationDraft(destination: destination, isNew: false) },
                    onRemove: { removingDestination = destination }
                )
            }
            KTSettingsRow(title: "Add destination", subtitle: "A local folder, an S3-compatible bucket or Google Drive.",
                          showDivider: false) {
                KTDropdown(width: 190, options: BackupDestinationKind.allCases.map { kind in
                    KTDropdownOption(label: kind.label, active: false) {
                        editingDestination = DestinationDraft(destination: DestinationEditor.blank(kind), isNew: true)
                    }
                }) {
                    KTSettingsMenuValue(text: "Add…")
                }
            }
        }
    }

    private var removalTitle: String {
        "Remove \"\(removingDestination?.name ?? "")\"?"
    }

    private var removalBinding: Binding<Bool> {
        Binding(get: { removingDestination != nil }, set: { if !$0 { removingDestination = nil } })
    }

    private var deletionBinding: Binding<Bool> {
        Binding(get: { deletingPlan != nil }, set: { if !$0 { deletingPlan = nil } })
    }

    @ViewBuilder
    private func removalButtons(_ destination: BackupDestination) -> some View {
        let affected = destinations.plans(using: destination.id)
        if affected.isEmpty {
            Button("Remove", role: .destructive) { remove(destination, reassignTo: nil) }
        } else {
            ForEach(destinations.destinations.filter { $0.id != destination.id }) { other in
                Button("Move plans to \(other.name)") { remove(destination, reassignTo: other.id) }
            }
            Button("Remove and pause plans", role: .destructive) { remove(destination, reassignTo: nil) }
        }
        Button("Cancel", role: .cancel) {}
    }

    private func removalMessage(_ destination: BackupDestination) -> String {
        let affected = destinations.plans(using: destination.id).map(\.name)
        let base = "Backups already stored there are not deleted. Saved credentials are removed from the Keychain."
        guard !affected.isEmpty else { return base }
        return "Used by: \(affected.joined(separator: ", ")). " + base
    }

    private func remove(_ destination: BackupDestination, reassignTo replacement: UUID?) {
        Task { try? await destinations.remove(destination, reassignTo: replacement) }
    }
}
