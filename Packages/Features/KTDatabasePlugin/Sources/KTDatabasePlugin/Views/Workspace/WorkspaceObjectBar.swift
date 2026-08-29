import KTPluginKit
import SwiftUI

enum TablePaneMode: String, CaseIterable, Identifiable {
    case data = "Data"
    case structure = "Structure"
    case er = "ER"

    var id: String { rawValue }
    var symbol: String {
        switch self {
        case .data: "tablecells"
        case .structure: "list.bullet.rectangle"
        case .er: "point.3.connected.trianglepath.dotted"
        }
    }
}

/// Thanh đối tượng: icon + tên bảng + khoá chính, và segmented Data/Structure/ER cho tab bảng.
struct WorkspaceObjectBar: View {
    @ObservedObject var vm: DatabaseV2ViewModel
    @Binding var mode: TablePaneMode
    var onInsert: () -> Void = {}
    var onDelete: (() -> Void)?

    var body: some View {
        HStack(spacing: 10) {
            RoundedRectangle(cornerRadius: 6)
                .fill(Color(hex: 0xFFF1E0))
                .frame(width: 22, height: 22)
                .overlay(
                    Image(systemName: "tablecells")
                        .font(.system(size: 11))
                        .foregroundStyle(KTEditorTheme.switcherIcon)
                )
            Text(vm.selectedTable?.name ?? "—")
                .font(.jbMono(14))
                .foregroundStyle(KTEditorTheme.label)
            if let meta = metaLabel {
                Text(meta)
                    .font(.jbMono(11.5))
                    .foregroundStyle(KTEditorTheme.label3)
            }
            Spacer()
            if mode == .data, vm.selectedTable != nil {
                rowActions
            }
            segmented
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(KTEditorTheme.window)
        .overlay(alignment: .bottom) { Divider().overlay(KTEditorTheme.separator) }
    }

    private var metaLabel: String? {
        guard vm.selectedTable != nil else { return nil }
        let pk = vm.columns.primaryKeyColumns.map(\.name)
        return pk.isEmpty ? "no PK" : "PK \(pk.joined(separator: ", "))"
    }

    private var rowActions: some View {
        HStack(spacing: 2) {
            V2IconButton(
                systemImage: "plus",
                tint: vm.canEdit ? KTEditorTheme.label2 : KTEditorTheme.label3
            ) { onInsert() }
                .disabled(!vm.canEdit)
            V2IconButton(
                systemImage: "trash",
                tint: onDelete != nil ? KTEditorTheme.Status.error : KTEditorTheme.label3
            ) { onDelete?() }
                .disabled(onDelete == nil)
            Rectangle().fill(KTEditorTheme.separator).frame(width: 1, height: 16).padding(.horizontal, 4)
        }
    }

    private var segmented: some View {
        HStack(spacing: 2) {
            ForEach(TablePaneMode.allCases) { tab in
                let isActive = tab == mode
                HStack(spacing: 6) {
                    Image(systemName: tab.symbol).font(.system(size: 11)).opacity(0.8)
                    Text(tab.rawValue).font(.system(size: 12))
                }
                .foregroundStyle(isActive ? KTEditorTheme.label : KTEditorTheme.label2)
                .padding(.horizontal, 12)
                .padding(.vertical, 5)
                .background(isActive ? KTEditorTheme.content2 : .clear, in: RoundedRectangle(cornerRadius: 7))
                .overlay {
                    if isActive { RoundedRectangle(cornerRadius: 7).stroke(KTEditorTheme.separator, lineWidth: 1) }
                }
                .contentShape(Rectangle())
                .onTapGesture { mode = tab }
            }
        }
    }
}
