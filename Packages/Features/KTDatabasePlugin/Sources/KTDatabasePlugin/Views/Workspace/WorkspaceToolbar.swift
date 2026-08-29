import KTPluginKit
import SwiftUI

/// Nội dung NSToolbar unified: trái ‹ › refresh, giữa pill trạng thái, phải Tìm/＋Query/Backups/New DB/inspector.
/// Gắn full-width trong một NSToolbarItem (PluginWindowController), đọc tab đang mở từ WorkspaceStore.
/// Backups/New DB là window-level: hiện cả khi chưa mở tab nào.
struct WorkspaceToolbar: View {
    @ObservedObject var workspace: WorkspaceStore

    var body: some View {
        if let session = workspace.activeSession {
            WorkspaceToolbarBar(workspace: workspace, vm: session.vm)
                .id(session.id)
        } else {
            HStack(spacing: 8) {
                Spacer(minLength: 0)
                WorkspaceWindowButtons(workspace: workspace)
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
            V2IconButton(
                systemImage: "chevron.left",
                tint: vm.canGoBack ? KTEditorTheme.label2 : KTEditorTheme.label3
            ) { vm.goBack() }
                .disabled(!vm.canGoBack)
            V2IconButton(
                systemImage: "chevron.right",
                tint: vm.canGoForward ? KTEditorTheme.label2 : KTEditorTheme.label3
            ) { vm.goForward() }
                .disabled(!vm.canGoForward)
            V2IconButton(systemImage: "arrow.clockwise", tint: KTEditorTheme.label2) {
                workspace.refreshActive()
            }
        }
    }

    private var rightCluster: some View {
        HStack(spacing: 4) {
            V2Button(title: "Tìm", systemImage: "magnifyingglass") {
                workspace.focusFilter()
            }
            V2Button(title: "Query", systemImage: "plus") {
                workspace.openQueryForActive()
            }
            WorkspaceWindowButtons(workspace: workspace)
            V2IconButton(
                systemImage: "sidebar.right",
                tint: workspace.inspectorVisible ? KTEditorTheme.accent : KTEditorTheme.label2
            ) { workspace.inspectorVisible.toggle() }
        }
    }
}

/// Window-level: Backups + New Database, gated theo connection đang chọn.
private struct WorkspaceWindowButtons: View {
    @ObservedObject var workspace: WorkspaceStore

    var body: some View {
        HStack(spacing: 4) {
            V2Button(title: "Backups", systemImage: "archivebox") {
                workspace.requestBackups()
            }
            .disabled(workspace.selectedProfileID == nil)
            V2Button(title: "New DB", systemImage: "plus.rectangle.on.folder") {
                workspace.requestNewDatabase()
            }
            .disabled(workspace.selectedProfileID == nil)
        }
    }
}
