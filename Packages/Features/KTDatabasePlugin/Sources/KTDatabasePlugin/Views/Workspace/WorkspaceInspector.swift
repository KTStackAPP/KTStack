import KTPluginKit
import SwiftUI

struct WorkspaceInspector: View {
    @ObservedObject var vm: DatabaseV2ViewModel
    @Binding var selectedRow: Int?

    var body: some View {
        VStack(spacing: 0) {
            header
            if let row = selectedRow, let result = vm.displayRows, row >= 0, row < result.rows.count {
                fields(columns: result.columns, cells: result.rows[row], rowIndex: row)
            } else {
                placeholder
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(KTEditorTheme.content)
    }

    private var header: some View {
        HStack {
            Text("Chi tiết dòng")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(KTEditorTheme.label)
            Spacer()
            if let row = selectedRow {
                Text("#\(vm.windowStart + row + 1)")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(KTEditorTheme.faint)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .overlay(alignment: .bottom) { Divider().overlay(KTEditorTheme.separator) }
    }

    private var placeholder: some View {
        EmptyStateView(
            symbol: "sidebar.right",
            title: "Chưa chọn dòng",
            message: "Chọn một dòng trong bảng để xem và sửa chi tiết các trường."
        )
    }

    private func fields(columns: [ColumnMeta], cells: [Cell], rowIndex: Int) -> some View {
        let originalCells = (rowIndex < (vm.rows?.rows.count ?? 0)) ? vm.rows?.rows[rowIndex] : nil
        let pkSet = Set(vm.columns.primaryKeyColumns.map(\.name))
        let fkSet = Set(vm.foreignKeys.map(\.fromColumn))
        let typeMap = Dictionary(vm.columns.map { ($0.name, $0.dataType) }, uniquingKeysWith: { a, _ in a })
        return ScrollView {
            VStack(spacing: 0) {
                ForEach(Array(columns.enumerated()), id: \.offset) { index, col in
                    let cell = index < cells.count ? cells[index] : .null
                    let original = (originalCells != nil && index < originalCells!.count) ? originalCells![index] : cell
                    let isModified = (original != cell)
                    let dataType: String = typeMap[col.name] ?? col.typeName ?? ""
                    let isPrimaryKey: Bool = pkSet.contains(col.name)
                    let isForeignKey: Bool = fkSet.contains(col.name)
                    let editable = vm.canEdit && vm.editableColumns.contains(col.name)
                    InspectorField(
                        columnName: col.name,
                        dataType: dataType,
                        isPrimaryKey: isPrimaryKey,
                        isForeignKey: isForeignKey,
                        cell: cell,
                        isModified: isModified,
                        editable: editable,
                        onCommit: { text in
                            vm.stageOrDraftEdit(row: rowIndex, column: index, value: text)
                        },
                        onSetNull: {
                            vm.stageOrDraftEdit(row: rowIndex, column: index, edit: .null)
                        }
                    )
                    .id("\(rowIndex)-\(col.name)")
                }
            }
        }
    }
}
