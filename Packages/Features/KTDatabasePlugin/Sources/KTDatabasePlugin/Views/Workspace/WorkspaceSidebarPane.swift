import AppKit
import KTPluginKit
import SwiftUI

struct WorkspaceSidebarPane: View {
    @ObservedObject var model: WorkspaceRootModel
    @ObservedObject var vm: DatabaseV2ViewModel
    @ObservedObject var workspace: WorkspaceStore

    var body: some View {
        VStack(spacing: 0) {
            searchField
            Divider().overlay(KTEditorTheme.separator)
            WorkspaceSidebar(
                nodes: model.nodes,
                selectedNodeID: model.selectedNodeID,
                onSelectObject: { model.selectObject($0, forceNewTab: false) },
                onOpenInNewTab: { model.selectObject($0, forceNewTab: true) },
                contextActions: { _ in [] }
            )
            Divider().overlay(KTEditorTheme.separator)
            footer
        }
    }

    private var searchField: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)
            TextField("Lọc bảng…", text: $model.filter)
                .textFieldStyle(.plain)
                .font(.system(size: 12))
            if !model.filter.isEmpty {
                Button { model.filter = "" } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Xoá bộ lọc")
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 6))
        .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color(nsColor: .separatorColor), lineWidth: 0.5))
        .padding(8)
    }

    private var footer: some View {
        let tables = model.currentObjects.filter { !$0.isView }.count
        let views = model.currentObjects.filter(\.isView).count
        return HStack(spacing: 6) {
            Text("\(tables) bảng · \(views) view")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
    }
}
