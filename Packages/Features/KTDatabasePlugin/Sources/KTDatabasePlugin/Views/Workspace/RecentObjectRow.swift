import KTPluginKit
import SwiftUI

/// Hàng "Mở gần đây": icon bảng/view, tên · profile/db, thời gian tương đối.
struct RecentObjectRow: View {
    let object: RecentObject
    let profileName: String
    let onOpen: () -> Void

    private static let relativeFormatter: RelativeDateTimeFormatter = {
        let f = RelativeDateTimeFormatter()
        f.unitsStyle = .abbreviated
        return f
    }()

    var body: some View {
        Button(action: onOpen) {
            HStack(spacing: 10) {
                Image(systemName: object.isView ? "eye" : "tablecells")
                    .font(.system(size: 12))
                    .foregroundStyle(KTEditorTheme.label2)
                    .frame(width: 18)
                VStack(alignment: .leading, spacing: 1) {
                    Text(object.name)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(KTEditorTheme.label)
                        .lineLimit(1)
                    Text("\(profileName) · \(object.database)")
                        .font(.system(size: 10.5))
                        .foregroundStyle(KTEditorTheme.label3)
                        .lineLimit(1)
                }
                Spacer(minLength: 8)
                Text(Self.relativeFormatter.localizedString(for: object.openedAt, relativeTo: Date()))
                    .font(.system(size: 10.5))
                    .foregroundStyle(KTEditorTheme.label3)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background(KTEditorTheme.rowHover, in: RoundedRectangle(cornerRadius: 7))
    }
}
