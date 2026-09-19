import KTPluginKit
import SwiftUI

struct WorkspaceInspectorPane: View {
    @ObservedObject var workspace: WorkspaceStore

    var body: some View {
        Group {
            if let session = workspace.activeSession, !session.kind.isQuery {
                ActiveInspector(session: session, vm: session.vm)
            } else {
                VStack(spacing: 8) {
                    Image(systemName: "sidebar.right")
                        .font(.system(size: 22))
                        .foregroundStyle(KTEditorTheme.faint)
                    Text("Chọn một dòng để xem chi tiết")
                        .font(.system(size: 12))
                        .foregroundStyle(KTEditorTheme.label3)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(KTEditorTheme.content2)
            }
        }
    }
}

private struct ActiveInspector: View {
    @ObservedObject var session: WorkspaceTabSession
    @ObservedObject var vm: DatabaseV2ViewModel

    var body: some View {
        WorkspaceInspector(vm: vm, selectedRow: $session.selectedRowIndex)
    }
}
