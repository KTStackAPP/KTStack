import KTPluginKit
import SwiftUI

struct V2StructureConstraintsSection: View {
    @ObservedObject var vm: DatabaseV2ViewModel
    let canEdit: Bool

    var body: some View {
        VStack(spacing: 0) {
            if !vm.indexes.isEmpty {
                indexesSection
            }
            if !foreignKeysForTable.isEmpty {
                foreignKeysSection
            }
            if !vm.checks.isEmpty {
                checksSection
            }
        }
    }

    private var indexesSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("INDEXES")
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundStyle(KTEditorTheme.label2)
                .padding(.bottom, 8)
            ForEach(vm.indexes) { index in
                HStack(spacing: 8) {
                    Image(systemName: index.isUnique ? "key.fill" : "number")
                        .font(.system(size: 11))
                        .foregroundStyle(KTEditorTheme.label2)
                    Text(index.name)
                        .font(.system(size: 12.5, design: .monospaced))
                        .foregroundStyle(KTEditorTheme.label)
                    Text("(\(index.columns.joined(separator: ", ")))")
                        .font(.system(size: 12.5, design: .monospaced))
                        .foregroundStyle(KTEditorTheme.label2)
                    if index.isUnique {
                        Text("UNIQUE")
                            .font(.system(size: 11, weight: .semibold, design: .monospaced))
                            .foregroundStyle(KTEditorTheme.accent)
                    }
                    Spacer()
                    if canEdit, index.name != "PRIMARY" {
                        Button {
                            vm.previewChanges([.dropIndex(index.name)], title: "Drop Index")
                        } label: {
                            Image(systemName: "trash")
                                .font(.system(size: 11))
                                .foregroundStyle(KTEditorTheme.Status.error)
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
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundStyle(KTEditorTheme.label2)
                .padding(.bottom, 8)
            ForEach(foreignKeysForTable) { fk in
                HStack(spacing: 8) {
                    Image(systemName: "link")
                        .font(.system(size: 11))
                        .foregroundStyle(KTEditorTheme.label2)
                    Text(fk.constraintName ?? "\(fk.fromColumn)")
                        .font(.system(size: 12.5, design: .monospaced))
                        .foregroundStyle(KTEditorTheme.label)
                    Text("\(fk.fromColumn) → \(fk.toTable).\(fk.toColumn)")
                        .font(.system(size: 12.5, design: .monospaced))
                        .foregroundStyle(KTEditorTheme.label2)
                    if let actions = fkActions(fk) {
                        Text(actions)
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundStyle(KTEditorTheme.label3)
                    }
                    Spacer()
                    if canEdit, let name = fk.constraintName {
                        Button {
                            vm.previewChanges([.dropForeignKey(name)], title: "Drop Foreign Key")
                        } label: {
                            Image(systemName: "trash")
                                .font(.system(size: 11))
                                .foregroundStyle(KTEditorTheme.Status.error)
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
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundStyle(KTEditorTheme.label2)
                .padding(.bottom, 8)
            ForEach(vm.checks) { check in
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.shield")
                        .font(.system(size: 11))
                        .foregroundStyle(KTEditorTheme.label2)
                    Text(check.name)
                        .font(.system(size: 12.5, design: .monospaced))
                        .foregroundStyle(KTEditorTheme.label)
                    Text(check.expression)
                        .font(.system(size: 12.5, design: .monospaced))
                        .foregroundStyle(KTEditorTheme.label2)
                        .lineLimit(1)
                    Spacer()
                    if canEdit {
                        Button {
                            vm.previewChanges([.dropCheck(check.name)], title: "Drop Check")
                        } label: {
                            Image(systemName: "trash")
                                .font(.system(size: 11))
                                .foregroundStyle(KTEditorTheme.Status.error)
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
}
