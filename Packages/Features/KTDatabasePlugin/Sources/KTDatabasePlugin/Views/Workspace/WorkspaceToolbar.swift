import KTPluginKit
import SwiftUI

struct WorkspaceToolbar: View {
    @ObservedObject var workspace: WorkspaceStore

    var body: some View {
        if let session = workspace.activeSession {
            WorkspaceToolbarBar(workspace: workspace, vm: session.vm)
                .id(session.id)
        } else {
            HStack(spacing: 8) {
                Button("Sidebar", systemImage: "sidebar.left") {
                    workspace.sidebarVisible.toggle()
                }
                .labelStyle(.iconOnly)
                .buttonStyle(.borderless)
                .foregroundStyle(workspace.sidebarVisible ? KTEditorTheme.accent : KTEditorTheme.label2)
                .help("Toggle Sidebar (⌘0)")

                Spacer(minLength: 0)
                WorkspaceWindowButtons(workspace: workspace)
                WorkspaceConnectionMenu(workspace: workspace)
            }
            .padding(.horizontal, 12)
            .frame(height: 30)
        }
    }
}

private struct WorkspaceToolbarBar: View {
    @ObservedObject var workspace: WorkspaceStore
    @ObservedObject var vm: DatabaseV2ViewModel

    var body: some View {
        HStack(spacing: 8) {
            leftCluster
            Spacer(minLength: 12)
            WorkspaceStatusPill(vm: vm, onSelectDatabase: workspace.selectDatabaseForActive)
            Spacer(minLength: 12)
            rightCluster
        }
        .padding(.horizontal, 12)
        .frame(height: 30)
    }

    private var leftCluster: some View {
        HStack(spacing: 4) {
            Button("Sidebar", systemImage: "sidebar.left") {
                workspace.sidebarVisible.toggle()
            }
            .labelStyle(.iconOnly)
            .buttonStyle(.borderless)
            .foregroundStyle(workspace.sidebarVisible ? KTEditorTheme.accent : KTEditorTheme.label2)
            .help("Toggle Sidebar (⌘0)")

            Button("Back", systemImage: "chevron.left") {
                vm.goBack()
            }
            .labelStyle(.iconOnly)
            .buttonStyle(.borderless)
            .disabled(!vm.canGoBack)
            .help("Back")

            Button("Forward", systemImage: "chevron.right") {
                vm.goForward()
            }
            .labelStyle(.iconOnly)
            .buttonStyle(.borderless)
            .disabled(!vm.canGoForward)
            .help("Forward")

            Button("Reload", systemImage: "arrow.clockwise") {
                workspace.refreshActive()
            }
            .labelStyle(.iconOnly)
            .buttonStyle(.borderless)
            .help("Reload (⌘R)")
        }
    }

    private var rightCluster: some View {
        HStack(spacing: 6) {
            Button("Filter", systemImage: "magnifyingglass") {
                workspace.focusFilter()
            }
            .labelStyle(.iconOnly)
            .buttonStyle(.borderless)
            .help("Filter Tables (⌘F)")

            Button("Query", systemImage: "plus") {
                workspace.openQueryForActive()
            }
            .labelStyle(.iconOnly)
            .buttonStyle(.borderless)
            .help("New Query Tab (⌘T)")

            WorkspaceWindowButtons(workspace: workspace)
            WorkspaceConnectionMenu(workspace: workspace)

            Button("Inspector", systemImage: "sidebar.right") {
                workspace.inspectorVisible.toggle()
            }
            .labelStyle(.iconOnly)
            .buttonStyle(.borderless)
            .foregroundStyle(workspace.inspectorVisible ? KTEditorTheme.accent : KTEditorTheme.label2)
            .help("Toggle Inspector (⌘⌥I)")
        }
    }
}

private struct WorkspaceConnectionMenu: View {
    @ObservedObject var workspace: WorkspaceStore

    var body: some View {
        Menu {
            Button("Disconnect") { workspace.requestDisconnect() }
                .disabled(workspace.selectedProfileID == nil)
            Button("Open Another Connection…") { workspace.requestOpenConnection() }
        } label: {
            Label("Connection Options", systemImage: "ellipsis.circle")
                .labelStyle(.iconOnly)
                .foregroundStyle(KTEditorTheme.label2)
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
    }
}

private struct WorkspaceWindowButtons: View {
    @ObservedObject var workspace: WorkspaceStore

    var body: some View {
        HStack(spacing: 4) {
            Button("Backups", systemImage: "archivebox") {
                workspace.requestBackups()
            }
            .labelStyle(.iconOnly)
            .buttonStyle(.borderless)
            .disabled(workspace.selectedProfileID == nil)
            .help("Manage Backups")

            Button("New Database", systemImage: "plus.rectangle.on.folder") {
                workspace.requestNewDatabase()
            }
            .labelStyle(.iconOnly)
            .buttonStyle(.borderless)
            .disabled(workspace.selectedProfileID == nil)
            .help("Create Database")
        }
    }
}
