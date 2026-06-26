import SwiftUI
import KTStackKit

struct QueryTabBar: View {
    @EnvironmentObject private var vm: DatabaseViewModel

    var body: some View {
        HStack(spacing: 0) {
            ForEach(vm.queryTabs) { tab in
                tabButton(tab)
            }
            addButton
            Spacer(minLength: 0)
        }
        .frame(height: 34)
        .background(KTEditorTheme.content2)
        .overlay(alignment: .bottom) { Rectangle().fill(KTEditorTheme.separator).frame(height: 1) }
    }

    private func tabButton(_ tab: QueryTab) -> some View {
        let active = tab.id == vm.activeQueryTabID
        return HStack(spacing: 8) {
            if tab.isBusy {
                ProgressView().controlSize(.mini).scaleEffect(0.65).frame(width: 12, height: 12)
            }
            Text(tab.title)
                .font(.jbMono(12))
                .foregroundStyle(active ? KTEditorTheme.label : KTEditorTheme.label2)
                .lineLimit(1)
                .frame(maxWidth: 150, alignment: .leading)
                .fixedSize(horizontal: true, vertical: false)
            if vm.queryTabs.count > 1 {
                Button { vm.closeQueryTab(tab.id) } label: {
                    Image(systemName: "xmark").font(.system(size: 10, weight: .regular))
                        .foregroundStyle(KTEditorTheme.label3)
                }
                .buttonStyle(.plain)
                .help("Close query tab")
            }
        }
        .padding(.horizontal, 12)
        .frame(maxHeight: .infinity)
        .background(active ? KTEditorTheme.content : Color.clear)
        .overlay(alignment: .trailing) { Rectangle().fill(KTEditorTheme.separator).frame(width: 1) }
        .contentShape(Rectangle())
        .onTapGesture { vm.selectQueryTab(tab.id) }
        .help(tab.sql.isEmpty ? tab.title : tab.sql)
    }

    private var addButton: some View {
        Button { vm.addQueryTab() } label: {
            Image(systemName: "plus").font(.system(size: 13, weight: .regular))
                .foregroundStyle(KTEditorTheme.label2)
                .padding(.horizontal, 12).frame(maxHeight: .infinity)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help("New query tab")
    }
}
