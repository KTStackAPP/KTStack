import KTPluginKit
import SwiftUI

/// Nội dung một tab bảng: objbar + filter inline + (grid | inspector) + status bar, trên VM riêng của tab.
/// Insert dùng dòng nháp inline (không sheet); filter/inspector thay các sheet cũ trong workspace.
struct WorkspaceTablePane: View {
    @ObservedObject var vm: DatabaseV2ViewModel
    @ObservedObject var workspace: WorkspaceStore
    // Quan sát session để chọn dòng (từ grid) cập nhật lại objbar Delete và inspector pane.
    @ObservedObject var session: WorkspaceTabSession

    @State private var mode: TablePaneMode = .data
    @State private var pendingDeleteRow: Int?

    var body: some View {
        VStack(spacing: 0) {
            WorkspaceObjectBar(
                vm: vm,
                mode: $mode,
                onInsert: { vm.beginInsertDraft() },
                onDelete: deleteAction
            )
            modeContent
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(KTEditorTheme.content)
        }
        .background(KTEditorTheme.window)
        .task(id: mode) {
            guard mode == .er, !vm.diagramLoaded else { return }
            await vm.loadDiagram()
        }
        .deleteRowAlert(vm: vm, pendingDeleteRow: $pendingDeleteRow)
    }

    private var deleteAction: (() -> Void)? {
        guard vm.canEdit, session.selectedRowIndex != nil else { return nil }
        return { pendingDeleteRow = session.selectedRowIndex }
    }

    @ViewBuilder
    private var modeContent: some View {
        switch mode {
        case .data:
            dataPane
        case .structure:
            V2StructureTabView(vm: vm)
        case .er:
            V2ERTabView(vm: vm)
        }
    }

    private var dataPane: some View {
        VStack(spacing: 0) {
            WorkspaceFilterBar(vm: vm, workspace: workspace)
            if vm.isDraftingInsert {
                draftBanner
            }
            if let errorMessage = vm.editError {
                errorBanner(errorMessage)
            }
            gridBody
            WorkspaceStatusBar(vm: vm)
        }
    }

    @ViewBuilder
    private var gridBody: some View {
        if vm.isLoadingRows, vm.rows == nil {
            placeholder { ProgressView() }
        } else if let result = vm.displayRows {
            KTDataGrid(
                result: result,
                selectedRow: $session.selectedRowIndex,
                onActivate: nil,
                onNearEnd: { Task { await vm.fetchMore() } },
                onNearTop: { Task { await vm.fetchPrevious() } },
                rowNumberOffset: vm.windowStart,
                editableColumns: vm.canEdit ? vm.editableColumns : [],
                onCommitEdit: { row, column, value in
                    vm.stageOrDraftEdit(row: row, column: column, value: value)
                },
                foreignKeyColumns: foreignKeyColumnNames,
                onNavigateFK: { row, column in vm.navigateForeignKey(row: row, column: column) },
                onPaste: vm.canEdit ? { cells in vm.stagePaste(cells) } : nil,
                onSetEdit: vm.canEdit ? { row, column, edit in vm.stageOrDraftEdit(row: row, column: column, edit: edit) } : nil,
                onOpenEditor: { row, column in vm.openCellEditor(row: row, column: column) },
                columnEditors: vm.canEdit ? columnEditorKinds : [:]
            )
        } else if let errorMessage = vm.loadError {
            placeholder {
                Text(errorMessage)
                    .font(.jbMono(12))
                    .foregroundStyle(KTEditorTheme.Status.error)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 16)
            }
        } else {
            placeholder {
                Text(vm.selectedTable == nil ? "Chọn một bảng" : "Không có dữ liệu")
                    .font(.jbMono(13))
                    .foregroundStyle(KTEditorTheme.label3)
            }
        }
    }

    private var draftBanner: some View {
        HStack(spacing: 8) {
            Image(systemName: "plus.circle").font(.system(size: 11)).foregroundStyle(KTEditorTheme.accent)
            Text("Đang thêm dòng — điền ô ở cuối bảng rồi Stage").font(.jbMono(12)).foregroundStyle(KTEditorTheme.label)
            Spacer()
            V2Button(title: "Huỷ", kind: .danger) { vm.cancelInsertDraft() }
            V2Button(title: "Stage dòng", kind: .primary) { vm.commitInsertDraft() }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(KTEditorTheme.accent.opacity(0.06))
        .overlay(alignment: .bottom) { Divider().overlay(KTEditorTheme.separator) }
    }

    private func errorBanner(_ message: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.circle").font(.system(size: 12)).foregroundStyle(KTEditorTheme.Status.error)
            Text(message).font(.jbMono(12)).foregroundStyle(KTEditorTheme.Status.error)
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 7)
        .background(KTEditorTheme.Status.error.opacity(0.08))
        .overlay(alignment: .bottom) { Divider().overlay(KTEditorTheme.separator) }
    }

    private func placeholder<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        VStack {
            Spacer()
            content()
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(KTEditorTheme.content)
    }

    private var foreignKeyColumnNames: Set<String> {
        guard let table = vm.selectedTable else { return [] }
        return Set(vm.foreignKeys.filter { $0.fromTable == table.name }.map(\.fromColumn))
    }

    private var columnEditorKinds: [String: CellEditorKind] {
        Dictionary(vm.columns.map { ($0.name, CellEditorKind.forColumn($0)) }, uniquingKeysWith: { first, _ in first })
    }
}

private extension View {
    func deleteRowAlert(vm: DatabaseV2ViewModel, pendingDeleteRow: Binding<Int?>) -> some View {
        alert(
            "Stage xoá dòng này?",
            isPresented: Binding(
                get: { pendingDeleteRow.wrappedValue != nil },
                set: { if !$0 { pendingDeleteRow.wrappedValue = nil } }
            )
        ) {
            Button("Huỷ", role: .cancel) { pendingDeleteRow.wrappedValue = nil }
            Button("Stage xoá", role: .destructive) {
                if let row = pendingDeleteRow.wrappedValue {
                    vm.stageDelete(row: row)
                    pendingDeleteRow.wrappedValue = nil
                }
            }
        } message: {
            Text("Đánh dấu 1 dòng từ \(vm.selectedTable?.name ?? "bảng") để xoá. Áp dụng khi Commit, có thể hoàn tác trước đó.")
        }
    }
}
