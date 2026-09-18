import KTPluginKit
import SwiftUI

struct V2StructureTabView: View {
    @ObservedObject var vm: DatabaseV2ViewModel

    @State private var sheet: StructureSheet?
    @State private var selectedColumnName: String?
    @State private var renameText = ""
    @State private var confirmRename = false
    @State private var confirmTruncate = false
    @State private var confirmDropTable = false
    @State private var confirmDropView = false

    private var canEdit: Bool { vm.canApplySchema }
    private var isView: Bool { vm.selectedTable?.isView ?? false }
    private var hasTable: Bool { vm.selectedTable != nil }

    var body: some View {
        VStack(spacing: 0) {
            V2StructureToolbar(
                vm: vm,
                canEdit: canEdit,
                isView: isView,
                hasTable: hasTable,
                confirmRename: $confirmRename,
                renameText: $renameText,
                confirmTruncate: $confirmTruncate,
                confirmDropTable: $confirmDropTable,
                confirmDropView: $confirmDropView,
                onOpenSheet: { sheet = $0 }
            )
            if let error = vm.ddlError {
                ddlErrorBanner(error)
            }
            content
        }
        .onChange(of: vm.selectedTable) { _ in selectedColumnName = nil }
        .sheet(item: $sheet) { active in sheetView(active) }
        .sheet(item: previewBinding) { preview in
            V2DDLPreviewSheet(vm: vm, preview: preview)
        }
        .alert("Rename Table", isPresented: $confirmRename) {
            TextField("new_name", text: $renameText)
            Button("Cancel", role: .cancel) {}
            Button("Rename") { Task { await vm.renameTable(to: renameText) } }
        }
        .alert("Truncate Table?", isPresented: $confirmTruncate) {
            Button("Cancel", role: .cancel) {}
            Button("Truncate", role: .destructive) { Task { await vm.truncateTable() } }
        } message: {
            Text("Delete every row in \(vm.selectedTable?.name ?? "").")
        }
        .alert("Drop Table?", isPresented: $confirmDropTable) {
            Button("Cancel", role: .cancel) {}
            Button("Drop", role: .destructive) {
                Task { await vm.runDDL(vm.composeDropTable()) }
            }
        } message: {
            Text("Drop \(vm.selectedTable?.name ?? "") and all its data.")
        }
        .alert("Drop View?", isPresented: $confirmDropView) {
            Button("Cancel", role: .cancel) {}
            Button("Drop", role: .destructive) { Task { await vm.dropView() } }
        } message: {
            Text("Drop view \(vm.selectedTable?.name ?? "").")
        }
    }

    private var previewBinding: Binding<DDLPreview?> {
        Binding(get: { vm.ddlPreview }, set: { if $0 == nil { vm.cancelPreview() } })
    }

    @ViewBuilder
    private func sheetView(_ active: StructureSheet) -> some View {
        switch active {
        case .newTable: V2CreateTableSheet(vm: vm)
        case .addColumn: V2ColumnEditorSheet(vm: vm, original: nil)
        case let .editColumn(name):
            V2ColumnEditorSheet(vm: vm, original: vm.columns.first { $0.name == name })
        case .addIndex: V2IndexEditorSheet(vm: vm)
        case .addForeignKey: V2ForeignKeySheet(vm: vm)
        case .addCheck: V2CheckConstraintSheet(vm: vm)
        case .tableOptions: V2TableOptionsSheet(vm: vm)
        case .createView: V2CreateViewSheet(vm: vm)
        case .ddlSource: V2DDLSourceSheet(vm: vm)
        }
    }

    @ViewBuilder
    private var content: some View {
        if !hasTable {
            centeredLabel("Select a table")
        } else if !vm.columns.isEmpty {
            ScrollView {
                VStack(spacing: 0) {
                    V2StructureColumnList(
                        vm: vm,
                        selectedColumnName: $selectedColumnName,
                        canEdit: canEdit,
                        isView: isView,
                        onEditColumn: { sheet = .editColumn($0) }
                    )
                    V2StructureConstraintsSection(vm: vm, canEdit: canEdit)
                    Spacer(minLength: 0)
                }
            }
        } else if let errorMessage = vm.loadError {
            centeredError(errorMessage)
        } else if vm.isLoadingStructure {
            centeredLabel("Loading…")
        } else {
            centeredLabel("No columns")
        }
    }

    private func ddlErrorBanner(_ message: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 12))
                .foregroundStyle(KTEditorTheme.Status.error)
            Text(message)
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(KTEditorTheme.Status.error)
                .lineLimit(2)
            Spacer()
            Button { vm.clearDDLError() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(KTEditorTheme.label2)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(KTEditorTheme.Status.error.opacity(0.08))
        .overlay(alignment: .bottom) { Divider().overlay(KTEditorTheme.separator) }
    }

    private func centeredLabel(_ text: String) -> some View {
        VStack {
            Spacer()
            Text(text)
                .font(.system(size: 13, design: .monospaced))
                .foregroundStyle(KTEditorTheme.label3)
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .background(KTEditorTheme.content)
    }

    private func centeredError(_ message: String) -> some View {
        VStack {
            Spacer()
            Text(message)
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(KTEditorTheme.Status.error)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .background(KTEditorTheme.content)
    }
}
