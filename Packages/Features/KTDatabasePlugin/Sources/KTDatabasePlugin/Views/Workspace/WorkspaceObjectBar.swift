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
                .font(.caption.weight(.medium))
                .foregroundStyle(Color.accentColor)
                .frame(width: 22, height: 22)
                .background(Color.accentColor.opacity(0.12), in: RoundedRectangle(cornerRadius: 6, style: .continuous))
            Text(vm.selectedTable?.name ?? "—")
                .font(.subheadline.bold().monospaced())
                .foregroundStyle(.primary)
            if let meta = metaLabel {
                Text(meta)
                    .font(.caption.monospaced())
                    .foregroundStyle(.tertiary)
            }
            Spacer()
            if mode == .data, vm.selectedTable != nil {
                rowActions
            }
            segmented
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color(nsColor: .windowBackgroundColor))
        .overlay(alignment: .bottom) { Divider().overlay(Color(nsColor: .separatorColor)) }
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
