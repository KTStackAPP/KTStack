import KTPluginKit
import SwiftUI

// Khung cửa sổ "KTStack Database": phase 1 mới chỉ split view + sidebar placeholder;
// phase 2 thay bằng WorkspaceSidebar/landing, phase 3 thay content bằng tab theo object.
struct DatabaseWorkspaceRoot: View {
    @ObservedObject var vm: DatabaseV2ViewModel
    let onClose: () -> Void

    var body: some View {
        HSplitView {
            sidebarPlaceholder
                .frame(minWidth: 232, idealWidth: 232, maxWidth: 320, maxHeight: .infinity)
                .background(KTEditorTheme.sidebar)

            DatabaseV2Root(vm: vm, onClose: onClose, showsTitlebar: false)
                .frame(minWidth: 640, maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(KTEditorTheme.window)
    }

    private var sidebarPlaceholder: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Connections")
                .font(.system(size: 11, weight: .bold))
                .tracking(0.5)
                .foregroundStyle(KTEditorTheme.label2)
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
            Spacer()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
