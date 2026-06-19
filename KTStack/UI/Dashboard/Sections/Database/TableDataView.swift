import SwiftUI
import KTStackKit


struct TableDataView: View {
    @EnvironmentObject private var vm: DatabaseViewModel
    @State private var selectedRow: Int?
    @State private var editor: EditorMode?
    @State private var pendingDelete: Int?

    
    enum EditorMode: Identifiable {
        case insert
        case edit(Int)
        var id: String { if case .edit(let r) = self { return "edit-\(r)" } else { return "insert" } }
    }

    var body: some View {
        VStack(spacing: 0) {
            toolbar
            Divider()
            grid
        }
        .sheet(item: $editor) { RowEditorView(mode: $0) }
        .alert("Delete this row?", isPresented: deleteConfirmBinding, presenting: pendingDelete) { row in
            Button("Delete", role: .destructive) { Task { await vm.deleteRow(at: row) } }
            Button("Cancel", role: .cancel) {}
        } message: { _ in Text("This permanently removes the row from the table.") }
        .alert("Edit failed", isPresented: editErrorBinding, presenting: vm.editError) { _ in
            Button("OK", role: .cancel) { vm.clearEditError() }
        } message: { Text($0) }
    }

    // MARK: - Grid

    @ViewBuilder
    private var grid: some View {
        if let result = vm.result, vm.isTableBrowse {
            ResultsGridView(result: result, selectedRow: $selectedRow,
                            onDoubleClick: { if vm.canEditRows { editor = .edit($0) } })
        } else if vm.selectedTable == nil {
            EmptyStateView(symbol: "tablecells", title: "No table selected",
                           message: "Pick a table in the schema tree to browse its rows.")
        } else if let error = vm.resultError {
            EmptyStateView(symbol: "exclamationmark.triangle",
                           title: "Couldn’t load rows", message: error)
        } else {
            ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    // MARK: - Toolbar

    private var toolbar: some View {
        HStack(spacing: KDSpacing.space2) {
            if let table = vm.selectedTable {
                Label(table.name, systemImage: table.isView ? "eye" : "tablecells")
                    .font(KDFont.footnote).foregroundStyle(.secondary)
            }
            if let reason = vm.editDisabledReason, vm.isTableBrowse {
                Label(reason, systemImage: "lock").font(KDFont.footnote).foregroundStyle(.tertiary)
            }
            Spacer()
            if vm.canEditRows { crudButtons }
            if vm.isTableBrowse {
                CSVExportButton(defaultName: vm.selectedTable?.name ?? "table")
            }
            pager
        }
        .padding(KDSpacing.space2)
    }

    private var crudButtons: some View {
        HStack(spacing: KDSpacing.space2) {
            Button { editor = .insert } label: { Image(systemName: "plus") }
                .help("Add row").disabled(vm.isBusy)
            Button { if let r = selectedRow { editor = .edit(r) } } label: { Image(systemName: "pencil") }
                .help("Edit selected row").disabled(selectedRow == nil || vm.isBusy)
            Button { pendingDelete = selectedRow } label: { Image(systemName: "trash") }
                .help("Delete selected row").disabled(selectedRow == nil || vm.isBusy)
            Divider().frame(height: 16)
        }
    }

    private var pager: some View {
        HStack(spacing: KDSpacing.space2) {
            if let result = vm.result, vm.isTableBrowse, result.rowCount > 0 {
                Text("rows \(vm.pageOffset + 1)–\(vm.pageOffset + result.rowCount)")
                    .font(KDFont.footnote).foregroundStyle(.secondary)
            }
            Button { Task { await vm.previousPage() } } label: { Image(systemName: "chevron.left") }
                .disabled(vm.pageOffset == 0 || vm.isBusy || vm.selectedTable == nil)
            Button { Task { await vm.nextPage() } } label: { Image(systemName: "chevron.right") }
                .disabled(!vm.hasMorePages || vm.isBusy)
        }
    }

    // MARK: - Alert bindings

    private var deleteConfirmBinding: Binding<Bool> {
        Binding(get: { pendingDelete != nil }, set: { if !$0 { pendingDelete = nil } })
    }

    private var editErrorBinding: Binding<Bool> {
        Binding(get: { vm.editError != nil }, set: { if !$0 { vm.clearEditError() } })
    }
}
