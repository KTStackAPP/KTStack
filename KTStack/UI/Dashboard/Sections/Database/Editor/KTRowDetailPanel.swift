import SwiftUI
import KTStackKit

struct KTRowDetailPanel: View {
    let columns: [ColumnMeta]
    let row: [Cell]?
    let onClose: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            header
            Rectangle().fill(KTColor.sep).frame(height: 0.5)
            if let row {
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(Array(columns.enumerated()), id: \.offset) { index, column in
                            fieldRow(name: column.name,
                                     cell: index < row.count ? row[index] : .null)
                        }
                    }
                }
            } else {
                placeholder
            }
        }
        .frame(width: 280)
        .background(KTColor.sidebarBackground)
    }

    private var header: some View {
        HStack {
            Text("Row Detail").font(.jbMono(12.5, .bold)).foregroundStyle(KTColor.ink2)
            Spacer()
            Button(action: onClose) {
                Image(systemName: "xmark").font(.system(size: 11, weight: .medium))
                    .foregroundStyle(KTColor.muted).frame(width: 22, height: 22).contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 14).padding(.vertical, 9)
    }

    private func fieldRow(name: String, cell: Cell) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(name).font(.jbMono(11, .medium)).foregroundStyle(KTColor.muted)
            if let text = cell.displayText {
                Text(text).font(.jbMono(12.5)).foregroundStyle(KTColor.ink2)
                    .textSelection(.enabled).lineLimit(6)
            } else {
                Text("NULL").font(.jbMono(12, .regular).italic()).foregroundStyle(KTColor.faint)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 14).padding(.vertical, 8)
        .overlay(alignment: .bottom) { Rectangle().fill(KTColor.sepFaint).frame(height: 0.5) }
    }

    private var placeholder: some View {
        VStack(spacing: 6) {
            Image(systemName: "sidebar.trailing").font(.system(size: 28, weight: .light)).foregroundStyle(KTColor.faint)
            Text("Select a row").font(.jbMono(12.5)).foregroundStyle(KTColor.muted)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
