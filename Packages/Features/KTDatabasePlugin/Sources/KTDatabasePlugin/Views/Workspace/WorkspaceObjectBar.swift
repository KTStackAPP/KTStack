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

struct WorkspaceObjectBar: View {
    @ObservedObject var vm: DatabaseV2ViewModel
    @Binding var mode: TablePaneMode
    var onInsert: () -> Void = {}
    var onDelete: (() -> Void)?

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "tablecells")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(KTEditorTheme.switcherIcon)
                .frame(width: 22, height: 22)
                .background(KTEditorTheme.switcherIcon.opacity(0.12), in: RoundedRectangle(cornerRadius: 6))
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
        HStack(spacing: 4) {
            Button("Thêm dòng", systemImage: "plus") {
                onInsert()
            }
            .labelStyle(.iconOnly)
            .buttonStyle(.borderless)
            .disabled(!vm.canEdit)
            .help("Thêm dòng mới (⌘N)")

            Button("Xoá dòng", systemImage: "trash") {
                onDelete?()
            }
            .labelStyle(.iconOnly)
            .buttonStyle(.borderless)
            .disabled(onDelete == nil)
            .help("Xoá dòng đang chọn")

            Divider().frame(height: 14).padding(.horizontal, 4)
        }
    }

    private var segmented: some View {
        Picker("View Mode", selection: $mode) {
            ForEach(TablePaneMode.allCases) { tab in
                Label(tab.rawValue, systemImage: tab.symbol).tag(tab)
            }
        }
        .pickerStyle(.segmented)
        .labelsHidden()
        .fixedSize()
    }
}
