import KTPluginKit
import SwiftUI

enum ColumnKeyKind {
    case primary
    case foreign
    case none
}

struct V2StructureColumnList: View {
    @ObservedObject var vm: DatabaseV2ViewModel
    @Binding var selectedColumnName: String?
    let canEdit: Bool
    let isView: Bool
    let onEditColumn: (String) -> Void

    var body: some View {
        VStack(spacing: 0) {
            columnHeader
            ForEach(vm.columns) { column in
                columnRow(column)
            }
        }
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
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(KTEditorTheme.label2)
            .frame(maxWidth: .infinity, alignment: .leading)
            .layoutPriority(priority)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
    }

    private func columnRow(_ column: ColumnInfo) -> some View {
        let isSelected = column.name == selectedColumnName
        return HStack(spacing: 0) {
            Text(column.name)
                .font(.system(size: 12.5, design: .monospaced))
                .foregroundStyle(isSelected ? .white : KTEditorTheme.label)
                .frame(maxWidth: .infinity, alignment: .leading)
                .layoutPriority(2)
                .padding(.horizontal, 16)
            Text(column.dataType)
                .font(.system(size: 12.5, design: .monospaced))
                .foregroundStyle(isSelected ? .white.opacity(0.85) : KTEditorTheme.Syntax.type)
                .frame(maxWidth: .infinity, alignment: .leading)
                .layoutPriority(2)
                .padding(.horizontal, 16)
            Text(column.isNullable ? "YES" : "NO")
                .font(.system(size: 12.5, design: .monospaced))
                .foregroundStyle(isSelected ? .white.opacity(0.7) : KTEditorTheme.label2)
                .frame(maxWidth: .infinity, alignment: .leading)
                .layoutPriority(1)
                .padding(.horizontal, 16)
            keyBadge(columnKey(for: column), selected: isSelected)
                .frame(maxWidth: .infinity, alignment: .leading)
                .layoutPriority(1)
                .padding(.horizontal, 16)
            Text(column.defaultValue ?? "-")
                .font(.system(size: 12.5, design: .monospaced))
                .foregroundStyle(isSelected ? .white.opacity(0.7) : KTEditorTheme.label2)
                .frame(maxWidth: .infinity, alignment: .leading)
                .layoutPriority(2)
                .padding(.horizontal, 16)
            if canEdit, !isView {
                rowActions(column, selected: isSelected)
            }
        }
        .padding(.vertical, 8)
        .background(isSelected ? KTEditorTheme.accent : .clear)
        .contentShape(Rectangle())
        .onTapGesture { selectedColumnName = isSelected ? nil : column.name }
        .overlay(alignment: .bottom) { Divider().overlay(KTEditorTheme.separator) }
    }

    private func rowActions(_ column: ColumnInfo, selected: Bool) -> some View {
        HStack(spacing: 6) {
            Button { onEditColumn(column.name) } label: {
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
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundStyle(selected ? .white : KTEditorTheme.accent)
                .padding(.horizontal, 7)
                .padding(.vertical, 2)
                .background(
                    selected ? Color.white.opacity(0.25) : KTEditorTheme.accentSoft,
                    in: RoundedRectangle(cornerRadius: 5)
                )
        case .foreign:
            Text("FK")
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundStyle(selected ? .white.opacity(0.85) : KTEditorTheme.accent)
        case .none:
            EmptyView()
        }
    }

    private func columnKey(for column: ColumnInfo) -> ColumnKeyKind {
        if column.isPrimaryKey { return .primary }
        let tableName = vm.selectedTable?.name ?? ""
        let isForeignKey = vm.foreignKeys.contains { $0.fromTable == tableName && $0.fromColumn == column.name }
        return isForeignKey ? .foreign : .none
    }
}
