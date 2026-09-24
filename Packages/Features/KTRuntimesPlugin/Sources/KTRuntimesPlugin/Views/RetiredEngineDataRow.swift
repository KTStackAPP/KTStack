import KTPlatformContracts
import KTPluginKit
import SwiftUI

struct RetiredEngineDataRow: View {
    let item: ServiceEngineRetiredData
    let restoreBlockReason: String?
    let onRestore: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text("\(item.engine.displayName) \(item.version) data")
                    .font(KTType.rowName).foregroundStyle(KTColor.ink)
                Text(detail)
                    .font(KTType.caption).foregroundStyle(KTColor.ink2)
                    .lineLimit(1).truncationMode(.middle)
                    .help(item.path)
            }
            Spacer(minLength: 8)
            KTButton(title: "Restore", systemImage: "arrow.uturn.backward", kind: .secondary, action: onRestore)
                .disabled(restoreBlockReason != nil)
                .opacity(restoreBlockReason != nil ? 0.4 : 1)
                .help(restoreBlockReason ?? "Move this data back into place for \(item.engine.displayName) \(item.version)")
            KTButton(title: "Delete data…", systemImage: "trash", kind: .danger, action: onDelete)
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 18)
        .frame(minHeight: 52)
    }

    private var detail: String {
        let removed = item.removedAt.formatted(date: .abbreviated, time: .shortened)
        return "Kept \(removed) · \(ByteCountFormatter.string(fromByteCount: item.sizeBytes, countStyle: .file)) · \(item.path)"
    }
}
