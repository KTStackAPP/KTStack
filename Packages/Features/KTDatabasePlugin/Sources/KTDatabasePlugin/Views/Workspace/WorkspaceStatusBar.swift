import KTPluginKit
import SwiftUI

/// Status bar gộp: trái range/trang/lọc, phải cụm staged (menu) + Commit ⌘⏎.
struct WorkspaceStatusBar: View {
    @ObservedObject var vm: DatabaseV2ViewModel

    @State private var showSQL = false
    @State private var sqlText = ""

    var body: some View {
        HStack(spacing: 12) {
            if vm.isLoadingRows { ProgressView().scaleEffect(0.6) }
            Text(rangeText)
                .font(.jbMono(11.5))
                .foregroundStyle(KTEditorTheme.label2)
            if let page = pageText {
                dot
                Text(page).font(.jbMono(11.5)).foregroundStyle(KTEditorTheme.label3)
            }
            if let filterCount = filterCount {
                dot
                Text("Đã lọc: \(filterCount) điều kiện")
                    .font(.jbMono(11.5))
                    .foregroundStyle(KTEditorTheme.accent)
            }
            Spacer()
            if vm.pendingChangeCount > 0 {
                stagedMenu
                V2Button(title: "Commit", kind: .primary) { Task { await vm.commitStaged() } }
                    .keyboardShortcut(.return, modifiers: .command)
                    .disabled(vm.isCommitting)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
        .background(KTEditorTheme.content2)
        .overlay(alignment: .top) { Divider().overlay(KTEditorTheme.separator) }
    }

    private var dot: some View {
        Circle().fill(KTEditorTheme.faint).frame(width: 3, height: 3)
    }

    private var loadedCount: Int { vm.rows?.rowCount ?? 0 }

    private var rangeText: String {
        guard loadedCount > 0 else { return "0 dòng" }
        let first = vm.windowStart + 1
        let last = vm.windowStart + loadedCount
        let total: String
        if vm.isCountingRows {
            total = "\(last)+"
        } else if let estimate = vm.rowCountEstimate {
            total = estimate.formatted(.number.grouping(.automatic))
        } else {
            total = vm.hasMore ? "\(last)+" : "\(last)"
        }
        return "\(first)–\(last) / \(total) dòng"
    }

    private var pageText: String? {
        guard loadedCount > 0 else { return nil }
        let page = vm.windowStart / vm.pageSize + 1
        if let estimate = vm.rowCountEstimate, estimate > 0 {
            let totalPages = (estimate + vm.pageSize - 1) / vm.pageSize
            return "Trang \(page) / \(totalPages)"
        }
        return "Trang \(page)"
    }

    private var filterCount: Int? {
        let count = vm.activeFilters.count
        return count > 0 ? count : nil
    }

    private var stagedMenu: some View {
        Menu {
            Button("Xem SQL") { presentSQL() }
            Divider()
            Button("Hoàn tác") { vm.undoStaged() }.disabled(!vm.canUndoStaged)
            Button("Làm lại") { vm.redoStaged() }.disabled(!vm.canRedoStaged)
            Divider()
            Button("Bỏ hết", role: .destructive) { vm.discardStaged() }
        } label: {
            HStack(spacing: 5) {
                Image(systemName: "square.and.pencil").font(.system(size: 10))
                Text("\(vm.pendingChangeCount) staged").font(.jbMono(11.5))
            }
            .foregroundStyle(KTEditorTheme.accent)
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
        .popover(isPresented: $showSQL) {
            ScrollView {
                Text(sqlText)
                    .font(.jbMono(11.5))
                    .foregroundStyle(KTEditorTheme.label)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(14)
            }
            .frame(width: 460, height: 240)
        }
    }

    private func presentSQL() {
        if let preview = try? vm.staged?.sqlPreview() {
            sqlText = preview.statements.joined(separator: "\n")
        } else {
            sqlText = "(không có thay đổi)"
        }
        showSQL = true
    }
}
