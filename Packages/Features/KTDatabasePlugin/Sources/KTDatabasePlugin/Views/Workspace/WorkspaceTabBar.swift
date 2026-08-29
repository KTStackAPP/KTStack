import KTPluginKit
import SwiftUI

/// Dải tab theo object (Xcode-style): chấm cam khi tab còn staged, nút đóng, nút + mở tab query.
struct WorkspaceTabBar: View {
    @ObservedObject var workspace: WorkspaceStore
    let onNewQuery: () -> Void
    let onClose: (UUID) -> Void

    var body: some View {
        HStack(spacing: 0) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 1) {
                    ForEach(workspace.tabs) { session in
                        WorkspaceTabItem(
                            session: session,
                            vm: session.vm,
                            isActive: session.id == workspace.activeTabID,
                            onSelect: { workspace.activate(session.id) },
                            onClose: { onClose(session.id) }
                        )
                    }
                }
                .padding(.horizontal, 8)
            }
            Button(action: onNewQuery) {
                Image(systemName: "plus")
                    .font(.system(size: 12))
                    .foregroundStyle(KTEditorTheme.label2)
                    .frame(width: 30, height: 30)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help("New query tab")
        }
        .frame(height: 34)
        .background(KTEditorTheme.content2)
        .overlay(alignment: .bottom) { Divider().overlay(KTEditorTheme.separator) }
    }
}

private struct WorkspaceTabItem: View {
    @ObservedObject var session: WorkspaceTabSession
    @ObservedObject var vm: DatabaseV2ViewModel
    let isActive: Bool
    let onSelect: () -> Void
    let onClose: () -> Void

    @State private var hovering = false

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: session.kind.isQuery ? "terminal" : "tablecells")
                .font(.system(size: 11))
                .foregroundStyle(isActive ? KTEditorTheme.accent : KTEditorTheme.label3)
            Text(session.kind.title)
                .font(.system(size: 12))
                .foregroundStyle(isActive ? KTEditorTheme.label : KTEditorTheme.label2)
                .lineLimit(1)
            if vm.pendingChangeCount > 0 {
                Circle().fill(KTEditorTheme.switcherIcon).frame(width: 6, height: 6)
            }
            if hovering || isActive {
                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(KTEditorTheme.label3)
                }
                .buttonStyle(.plain)
                .help("Close tab")
            }
        }
        .padding(.horizontal, 11)
        .frame(height: 34)
        .background(isActive ? KTEditorTheme.content : .clear)
        .overlay(alignment: .bottom) {
            if isActive { Rectangle().fill(KTEditorTheme.accent).frame(height: 1.5) }
        }
        .contentShape(Rectangle())
        .onTapGesture(perform: onSelect)
        .onHover { hovering = $0 }
    }
}
