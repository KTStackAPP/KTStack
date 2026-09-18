import AppKit
import KTPluginKit
import SwiftUI

struct WorkspaceSidebarPane: View {
    @ObservedObject var model: WorkspaceRootModel
    @ObservedObject var vm: DatabaseV2ViewModel
    @ObservedObject var workspace: WorkspaceStore

    var body: some View {
        if model.isConnected {
            connectedSidebar
        } else {
            disconnectedSidebar
        }
    }

    private var connectedSidebar: some View {
        VStack(spacing: 0) {
            searchField
            Divider().overlay(Color(nsColor: .separatorColor))
            WorkspaceSidebar(
                nodes: model.nodes,
                selectedNodeID: model.selectedNodeID,
                onSelectObject: { model.selectObject($0, forceNewTab: false) },
                onOpenInNewTab: { model.selectObject($0, forceNewTab: true) },
                contextActions: { _ in [] }
            )
            Divider().overlay(Color(nsColor: .separatorColor))
            footer
        }
    }

    private var disconnectedSidebar: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                Image(systemName: "server.rack")
                    .font(.subheadline)
                    .foregroundStyle(Color.accentColor)
                Text("Connections")
                    .font(.headline)
                    .foregroundStyle(.primary)
                Spacer()
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            Divider().overlay(Color(nsColor: .separatorColor))
            List(selection: $workspace.selectedProfileID) {
                let managed = workspace.profiles.filter(\.isManaged)
                if !managed.isEmpty {
                    Section("Managed") {
                        ForEach(managed) { profile in
                            connectionRow(profile)
                        }
                    }
                }
                let userProfiles = workspace.profiles.filter { !$0.isManaged }
                if !userProfiles.isEmpty {
                    Section("Saved") {
                        ForEach(userProfiles) { profile in
                            connectionRow(profile)
                        }
                    }
                }
            }
            .listStyle(.sidebar)
        }
    }

    private func connectionRow(_ profile: ConnectionProfile) -> some View {
        HStack(spacing: 8) {
            Image(systemName: SidebarNode.icon(for: profile.kind))
                .font(.caption)
                .foregroundStyle(Color.accentColor)
            Text(profile.displayTitle())
                .font(.subheadline)
                .lineLimit(1)
            Spacer()
        }
        .tag(profile.id)
        .contentShape(Rectangle())
        .onTapGesture(count: 2) {
            model.activate(profileID: profile.id)
        }
    }

    private var searchField: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .font(.footnote)
                .foregroundStyle(.secondary)
            TextField("Filter tables…", text: $model.filter)
                .textFieldStyle(.plain)
                .font(.subheadline)
            if !model.filter.isEmpty {
                Button { model.filter = "" } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Clear filter")
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 6, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 6, style: .continuous).stroke(Color(nsColor: .separatorColor), lineWidth: 0.5))
        .padding(8)
    }

    private var footer: some View {
        let tables = model.currentObjects.filter { !$0.isView }.count
        let views = model.currentObjects.filter(\.isView).count
        return HStack(spacing: 6) {
            Text("\(tables) tables · \(views) views")
                .font(.footnote)
                .foregroundStyle(.secondary)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
    }
}
