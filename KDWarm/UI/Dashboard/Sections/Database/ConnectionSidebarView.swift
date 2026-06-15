import SwiftUI
import KDWarmKit

/// Left pane: the connection picker. Lists the always-present managed engine first, then saved
/// profiles, and fires `DatabaseViewModel.select(profile:)` on tap. The live connection state shows
/// inline on the selected row so "connecting"/"failed" is visible where the user picked.
struct ConnectionSidebarView: View {
    @EnvironmentObject private var store: ConnectionStore
    @EnvironmentObject private var vm: DatabaseViewModel
    @State private var sheet: SheetMode?

    /// Which form the add/edit sheet is showing. `Identifiable` so `.sheet(item:)` rebinds when the
    /// edited profile changes.
    enum SheetMode: Identifiable {
        case add
        case edit(ConnectionProfile)
        var id: String {
            switch self {
            case .add: return "add"
            case .edit(let profile): return profile.id.uuidString
            }
        }
        /// The profile to prefill, or nil when adding.
        var editingProfile: ConnectionProfile? {
            if case .edit(let profile) = self { return profile }
            return nil
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: KDSpacing.space2) {
                Text("Connections")
                    .font(KDFont.footnote).foregroundStyle(.secondary)
                Spacer(minLength: 0)
                Button { sheet = .add } label: { Image(systemName: "plus") }
                    .buttonStyle(.borderless).help("Add a connection")
            }
            .padding(.horizontal, KDSpacing.space3)
            .padding(.vertical, KDSpacing.space2)
            Divider()
            List {
                ForEach(store.allProfiles) { profile in
                    row(profile)
                        .contentShape(Rectangle())
                        .onTapGesture { Task { await vm.select(profile: profile) } }
                        .contextMenu { rowMenu(profile) }
                }
            }
            .listStyle(.sidebar)
        }
        .frame(minWidth: 180, idealWidth: 200)
        .sheet(item: $sheet) { mode in
            AddConnectionSheet(editing: mode.editingProfile)
                .environmentObject(store)
        }
    }

    /// Edit/Delete are only meaningful for saved profiles — the synthetic managed engine has neither.
    @ViewBuilder
    private func rowMenu(_ profile: ConnectionProfile) -> some View {
        if !profile.isManaged {
            Button("Edit…") { sheet = .edit(profile) }
            Button("Delete", role: .destructive) { store.remove(profile) }
        }
    }

    @ViewBuilder
    private func row(_ profile: ConnectionProfile) -> some View {
        let isSelected = vm.selectedProfile?.id == profile.id
        HStack(spacing: KDSpacing.space2) {
            Image(systemName: profile.kind == .mysql ? "cylinder.split.1x2" : "cylinder")
                .foregroundStyle(isSelected ? Color.accentColor : .secondary)
            VStack(alignment: .leading, spacing: 1) {
                Text(profile.name).font(KDFont.body)
                Text(profile.isManaged ? "managed · loopback" : "\(profile.host):\(profile.port)")
                    .font(KDFont.footnote).foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
            if isSelected { stateIcon }
        }
        .padding(.vertical, KDSpacing.space1)
    }

    @ViewBuilder
    private var stateIcon: some View {
        switch vm.connection {
        case .connecting:
            ProgressView().controlSize(.small)
        case .connected:
            Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
        case .failed:
            Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange)
        case .idle:
            EmptyView()
        }
    }
}
