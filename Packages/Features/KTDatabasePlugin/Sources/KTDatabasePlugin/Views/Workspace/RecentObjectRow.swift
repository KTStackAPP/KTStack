import KTPluginKit
import SwiftUI

struct RecentObjectRow: View {
    let object: RecentObject
    let profileName: String
    let onOpen: () -> Void

    private static let relativeFormatter: RelativeDateTimeFormatter = {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter
    }()

    var body: some View {
        Button(action: onOpen) {
            HStack(spacing: 10) {
                Image(systemName: object.isView ? "eye" : "tablecells")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(width: 18)
                VStack(alignment: .leading, spacing: 1) {
                    Text(object.name)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    Text("\(profileName) · \(object.database)")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                }
                Spacer(minLength: 8)
                Text(Self.relativeFormatter.localizedString(for: object.openedAt, relativeTo: Date()))
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background(Color(nsColor: .selectedContentBackgroundColor).opacity(0.08), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}
