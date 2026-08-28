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

    private enum StructureSheet: Identifiable {
        case newTable, addColumn, editColumn(String), addIndex, addForeignKey, addCheck, tableOptions, createView, ddlSource
        var id: String {
            switch self {
            case .newTable: "newTable"
            case .addColumn: "addColumn"
            case let .editColumn(name): "editColumn:\(name)"
            case .addIndex: "addIndex"
            case .addForeignKey: "addForeignKey"
            case .addCheck: "addCheck"
            case .tableOptions: "tableOptions"
            case .createView: "createView"
            case .ddlSource: "ddlSource"
            }
        }
    }

    private enum ColumnKeyKind { case primary, foreign, none }

    private var canEdit: Bool { vm.canApplySchema }
    private var isView: Bool { vm.selectedTable?.isView ?? false }
    private var hasTable: Bool { vm.selectedTable != nil }

    var body: some View {
        VStack(spacing: 0) {
            toolbar
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
                    columnHeader
                    ForEach(vm.columns) { columnRow($0) }
                    if !vm.indexes.isEmpty { indexesSection }
                    if !foreignKeysForTable.isEmpty { foreignKeysSection }
                    if !vm.checks.isEmpty { checksSection }
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

    private var toolbar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                V2Button(title: "New Table", systemImage: "plus") { sheet = .newTable }
                    .disabled(!canEdit)
                V2Button(title: "New View", systemImage: "eye") { sheet = .createView }
                    .disabled(!canEdit)
                if hasTable {
                    Divider().frame(height: 18)
                    V2Button(title: "DDL Source", systemImage: "doc.text") { sheet = .ddlSource }
                    if isView {
                        V2Button(title: "Drop View", kind: .danger) { confirmDropView = true }
                            .disabled(!canEdit)
                    } else {
                        V2Button(title: "Add Column", systemImage: "plus.rectangle") { sheet = .addColumn }
                            .disabled(!canEdit)
                        V2Button(title: "Add Index", systemImage: "number") { sheet = .addIndex }
                            .disabled(!canEdit)
                        V2Button(title: "Add FK", systemImage: "link") { sheet = .addForeignKey }
                            .disabled(!canEdit)
                        V2Button(title: "Add Check", systemImage: "checkmark.shield") { sheet = .addCheck }
                            .disabled(!canEdit)
                        V2Button(title: "Options", systemImage: "gearshape") { sheet = .tableOptions }
                            .disabled(!canEdit)
                        V2Button(title: "Rename", systemImage: "pencil") {
                            renameText = vm.selectedTable?.name ?? ""
                            confirmRename = true
                        }
                        .disabled(!canEdit)
                        V2Button(title: "Truncate", kind: .danger) { confirmTruncate = true }
                            .disabled(!canEdit)
                        V2Button(title: "Drop Table", kind: .danger) { confirmDropTable = true }
                            .disabled(!canEdit)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
        .overlay(alignment: .bottom) { Divider().overlay(KTEditorTheme.separator) }
    }

    private func ddlErrorBanner(_ message: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 12))
                .foregroundStyle(KTEditorTheme.Status.error)
            Text(message)
                .font(.system(size: 12))
                .foregroundStyle(KTEditorTheme.Status.error)
                .lineLimit(2)
            Spacer()
            Button { vm.clearDDLError() } label: {
                Image(systemName: "xmark").font(.system(size: 11)).foregroundStyle(KTEditorTheme.label3)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(KTEditorTheme.Status.error.opacity(0.08))
        .overlay(alignment: .bottom) { Divider().overlay(KTEditorTheme.separator) }
    }

    private var columnHeader: some View {
        HStack(spacing: 0) {
            headerCell("name", priority: 2)
            headerCell("type", priority: 2)
            headerCell("nullable", priority: 1)
            headerCell("key", priority: 1)
            headerCell("default", priority: 2)
            if canEdit, !isView {
                Color.clear.frame(width: 68)
            }
        }
        .background(KTEditorTheme.Grid.headerBg)
        .overlay(alignment: .bottom) { Divider().overlay(KTEditorTheme.separator) }
    }

    private func headerCell(_ title: String, priority: Double) -> some View {
        Text(title)
            .font(.system(size: 12))
            .foregroundStyle(KTEditorTheme.label2)
            .frame(maxWidth: .infinity, alignment: .leading)
            .layoutPriority(priority)
            .padding(.horizontal, 16)
            .padding(.vertical, 9)
    }

    private func columnRow(_ column: ColumnInfo) -> some View {
        let isSelected = column.name == selectedColumnName
        return HStack(spacing: 0) {
            Text(column.name)
                .font(.jbMono(12.5))
                .foregroundStyle(isSelected ? .white : KTEditorTheme.label)
                .frame(maxWidth: .infinity, alignment: .leading)
                .layoutPriority(2)
                .padding(.horizontal, 16)
            Text(column.dataType)
                .font(.jbMono(12.5))
                .foregroundStyle(isSelected ? .white.opacity(0.85) : KTEditorTheme.Syntax.type)
                .frame(maxWidth: .infinity, alignment: .leading)
                .layoutPriority(2)
                .padding(.horizontal, 16)
            Text(column.isNullable ? "YES" : "NO")
                .font(.jbMono(12.5))
                .foregroundStyle(isSelected ? .white.opacity(0.7) : KTEditorTheme.label2)
                .frame(maxWidth: .infinity, alignment: .leading)
                .layoutPriority(1)
                .padding(.horizontal, 16)
            keyBadge(columnKey(for: column), selected: isSelected)
                .frame(maxWidth: .infinity, alignment: .leading)
                .layoutPriority(1)
                .padding(.horizontal, 16)
            Text(column.defaultValue ?? "-")
                .font(.jbMono(12.5))
                .foregroundStyle(isSelected ? .white.opacity(0.7) : KTEditorTheme.label2)
                .frame(maxWidth: .infinity, alignment: .leading)
                .layoutPriority(2)
                .padding(.horizontal, 16)
            if canEdit, !isView {
                rowActions(column, selected: isSelected)
            }
        }
        .padding(.vertical, 9)
        .background(isSelected ? KTEditorTheme.accent : .clear)
        .contentShape(Rectangle())
        .onTapGesture { selectedColumnName = isSelected ? nil : column.name }
        .overlay(alignment: .bottom) { Divider().overlay(KTEditorTheme.separator) }
    }

    private func rowActions(_ column: ColumnInfo, selected: Bool) -> some View {
        HStack(spacing: 6) {
            Button { sheet = .editColumn(column.name) } label: {
                Image(systemName: "pencil")
                    .foregroundStyle(selected ? .white : KTEditorTheme.label2)
            }
            .buttonStyle(.plain)
            Button { vm.previewChanges([.dropColumn(column.name)], title: "Drop Column") } label: {
                Image(systemName: "trash")
                    .foregroundStyle(selected ? .white.opacity(0.85) : KTEditorTheme.Status.error)
            }
            .buttonStyle(.plain)
        }
        .font(.system(size: 12))
        .frame(width: 68)
    }

    @ViewBuilder
    private func keyBadge(_ key: ColumnKeyKind, selected: Bool) -> some View {
        switch key {
        case .primary:
            Text("PK")
                .font(.jbMono(11, .bold))
                .foregroundStyle(selected ? .white : KTEditorTheme.accent)
                .padding(.horizontal, 7)
                .padding(.vertical, 2)
                .background(
                    selected ? Color.white.opacity(0.25) : KTEditorTheme.accentSoft,
                    in: RoundedRectangle(cornerRadius: 5)
                )
        case .foreign:
            Text("FK")
                .font(.jbMono(11, .bold))
                .foregroundStyle(selected ? .white.opacity(0.85) : KTEditorTheme.accent)
        case .none:
            Text("")
        }
    }

    private var indexesSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("INDEXES")
                .font(.jbMono(12.5, .bold))
                .foregroundStyle(KTEditorTheme.label2)
                .padding(.bottom, 8)
            ForEach(vm.indexes) { index in
                HStack(spacing: 8) {
                    Image(systemName: index.isUnique ? "key.fill" : "number")
                        .font(.system(size: 11))
                        .foregroundStyle(KTEditorTheme.label2)
                    Text(index.name).font(.jbMono(12.5)).foregroundStyle(KTEditorTheme.label)
                    Text("(\(index.columns.joined(separator: ", ")))")
                        .font(.jbMono(12.5)).foregroundStyle(KTEditorTheme.label2)
                    if index.isUnique {
                        Text("UNIQUE").font(.jbMono(11)).foregroundStyle(KTEditorTheme.accent)
                    }
                    Spacer()
                    if canEdit, index.name != "PRIMARY" {
                        Button { vm.previewChanges([.dropIndex(index.name)], title: "Drop Index") } label: {
                            Image(systemName: "trash").font(.system(size: 11)).foregroundStyle(KTEditorTheme.Status.error)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.vertical, 7)
                .overlay(alignment: .bottom) { Divider().overlay(KTEditorTheme.separator) }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }

    private var foreignKeysForTable: [ForeignKeyRelation] {
        let tableName = vm.selectedTable?.name ?? ""
        return vm.foreignKeys.filter { $0.fromTable == tableName }
    }

    private var foreignKeysSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("FOREIGN KEYS")
                .font(.jbMono(12.5, .bold))
                .foregroundStyle(KTEditorTheme.label2)
                .padding(.bottom, 8)
            ForEach(foreignKeysForTable) { fk in
                HStack(spacing: 8) {
                    Image(systemName: "link").font(.system(size: 11)).foregroundStyle(KTEditorTheme.label2)
                    Text(fk.constraintName ?? "\(fk.fromColumn)")
                        .font(.jbMono(12.5)).foregroundStyle(KTEditorTheme.label)
                    Text("\(fk.fromColumn) → \(fk.toTable).\(fk.toColumn)")
                        .font(.jbMono(12.5)).foregroundStyle(KTEditorTheme.label2)
                    if let actions = fkActions(fk) {
                        Text(actions).font(.jbMono(11)).foregroundStyle(KTEditorTheme.label3)
                    }
                    Spacer()
                    if canEdit, let name = fk.constraintName {
                        Button { vm.previewChanges([.dropForeignKey(name)], title: "Drop Foreign Key") } label: {
                            Image(systemName: "trash").font(.system(size: 11)).foregroundStyle(KTEditorTheme.Status.error)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.vertical, 7)
                .overlay(alignment: .bottom) { Divider().overlay(KTEditorTheme.separator) }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }

    private func fkActions(_ fk: ForeignKeyRelation) -> String? {
        var parts: [String] = []
        if let onDelete = fk.onDelete { parts.append("ON DELETE \(onDelete.rawValue)") }
        if let onUpdate = fk.onUpdate { parts.append("ON UPDATE \(onUpdate.rawValue)") }
        return parts.isEmpty ? nil : parts.joined(separator: "  ")
    }

    private var checksSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("CHECKS")
                .font(.jbMono(12.5, .bold))
                .foregroundStyle(KTEditorTheme.label2)
                .padding(.bottom, 8)
            ForEach(vm.checks) { check in
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.shield").font(.system(size: 11)).foregroundStyle(KTEditorTheme.label2)
                    Text(check.name).font(.jbMono(12.5)).foregroundStyle(KTEditorTheme.label)
                    Text(check.expression).font(.jbMono(12.5)).foregroundStyle(KTEditorTheme.label2).lineLimit(1)
                    Spacer()
                    if canEdit {
                        Button { vm.previewChanges([.dropCheck(check.name)], title: "Drop Check") } label: {
                            Image(systemName: "trash").font(.system(size: 11)).foregroundStyle(KTEditorTheme.Status.error)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.vertical, 7)
                .overlay(alignment: .bottom) { Divider().overlay(KTEditorTheme.separator) }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }

    private func columnKey(for column: ColumnInfo) -> ColumnKeyKind {
        if column.isPrimaryKey { return .primary }
        let tableName = vm.selectedTable?.name ?? ""
        let isForeignKey = vm.foreignKeys.contains { $0.fromTable == tableName && $0.fromColumn == column.name }
        return isForeignKey ? .foreign : .none
    }

    private func centeredLabel(_ text: String) -> some View {
        VStack {
            Spacer()
            Text(text).font(.jbMono(13)).foregroundStyle(KTEditorTheme.label3)
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .background(KTEditorTheme.content)
    }

    private func centeredError(_ message: String) -> some View {
        VStack {
            Spacer()
            Text(message)
                .font(.jbMono(12))
                .foregroundStyle(KTEditorTheme.Status.error)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .background(KTEditorTheme.content)
    }
}
