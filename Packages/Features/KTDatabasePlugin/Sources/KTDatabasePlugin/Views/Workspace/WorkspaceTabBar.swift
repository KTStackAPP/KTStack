import KTPluginKit
import SwiftUI

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
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
                    .frame(width: 24, height: 24)
                    .background(Color(nsColor: .controlBackgroundColor).opacity(0.6), in: RoundedRectangle(cornerRadius: 5))
            }
            .buttonStyle(.plain)
            .help("New query tab")
            .padding(.trailing, 8)
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
    @State private var closeHovering = false
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
        .padding(.horizontal, 10)
        .frame(height: 26)
        .background(
            isActive ? Color(nsColor: .controlBackgroundColor) : (hovering ? Color(nsColor: .quaternaryLabelColor).opacity(0.4) : .clear),
            in: RoundedRectangle(cornerRadius: 6)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(isActive ? Color(nsColor: .separatorColor).opacity(0.6) : .clear, lineWidth: 0.5)
        )
        .contentShape(RoundedRectangle(cornerRadius: 6))
        .onTapGesture(perform: onSelect)
        .onHover { hovering = $0 }
    }
}
