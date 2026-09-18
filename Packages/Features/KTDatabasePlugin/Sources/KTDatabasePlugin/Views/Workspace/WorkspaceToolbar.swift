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
            Button("Quay lại", systemImage: "chevron.left") {
                vm.goBack()
            }
            .labelStyle(.iconOnly)
            .buttonStyle(.borderless)
            .disabled(!vm.canGoBack)
            .help("Quay lại bảng trước")

            Button("Tiếp theo", systemImage: "chevron.right") {
                vm.goForward()
            }
            .labelStyle(.iconOnly)
            .buttonStyle(.borderless)
            .disabled(!vm.canGoForward)
            .help("Đi tới bảng tiếp theo")

            Button("Tải lại", systemImage: "arrow.clockwise") {
                workspace.refreshActive()
            }
            .labelStyle(.iconOnly)
            .buttonStyle(.borderless)
            .help("Tải lại dữ liệu (⌘R)")
        }
    }

    private var rightCluster: some View {
        HStack(spacing: 6) {
            Button("Tìm", systemImage: "magnifyingglass") {
                workspace.focusFilter()
            }
            .labelStyle(.iconOnly)
            .buttonStyle(.borderless)
            .help("Lọc bảng (⌘F)")

            Button("Query", systemImage: "plus") {
                workspace.openQueryForActive()
            }
            .labelStyle(.iconOnly)
            .buttonStyle(.borderless)
            .help("Mở tab Query mới (⌘T)")

            WorkspaceWindowButtons(workspace: workspace)
            WorkspaceConnectionMenu(workspace: workspace)

            Button("Inspector", systemImage: "sidebar.right") {
                workspace.inspectorVisible.toggle()
            }
            .labelStyle(.iconOnly)
            .buttonStyle(.borderless)
            .foregroundStyle(workspace.inspectorVisible ? KTEditorTheme.accent : KTEditorTheme.label2)
            .help("Bật/tắt Inspector (⌘⌥I)")
        }
    }
}

private struct WorkspaceConnectionMenu: View {
    @ObservedObject var workspace: WorkspaceStore

    var body: some View {
        Menu {
            Button("Ngắt kết nối") { workspace.requestDisconnect() }
                .disabled(workspace.selectedProfileID == nil)
            Button("Mở kết nối khác…") { workspace.requestOpenConnection() }
        } label: {
            Label("Tuỳ chọn kết nối", systemImage: "ellipsis.circle")
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
            .help("Quản lý bản sao lưu")

            Button("New DB", systemImage: "plus.rectangle.on.folder") {
                workspace.requestNewDatabase()
            }
            .labelStyle(.iconOnly)
            .buttonStyle(.borderless)
            .disabled(workspace.selectedProfileID == nil)
            .help("Tạo cơ sở dữ liệu mới")
        }
    }
}
