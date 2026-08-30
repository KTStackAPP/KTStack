import KTPluginKit
import SwiftUI

/// Hàng kết nối đã lưu: badge LOCAL/REMOTE, dòng phụ, nút Open.
struct SavedConnectionRow: View {
    let profile: ConnectionProfile
    let status: ServerStatus
    let isSelected: Bool
    let onOpen: () -> Void

    var body: some View {
        HStack(spacing: KTSpacing.md) {
            KTIconTile(tint: KTEngineTint.of(profile.kind.rawValue), size: 34, radius: 9) {
                Image(systemName: "cylinder.split.1x2").font(.system(size: 14))
            }
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: KTSpacing.sm) {
                    Text(profile.name).font(KTType.rowName).foregroundStyle(KTColor.ink).lineLimit(1)
                    KTBadge(
                        text: isLocal ? "LOCAL" : "REMOTE",
                        tint: isLocal ? KTIconTint.globe : KTIconTint.neutral
                    )
                }
                HStack(spacing: 6) {
                    KTDot(color: statusColor, size: 7)
                    Text(profile.subtitle)
                        .font(KTType.monoSmall)
                        .foregroundStyle(KTColor.muted)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
            }
            Spacer(minLength: KTSpacing.sm)
            KTButton(title: "Open", kind: .primary, action: onOpen)
                .keyboardShortcut(isSelected ? .defaultAction : nil)
        }
        .padding(.vertical, KTSpacing.sm)
    }

    private var isLocal: Bool {
        profile.kind == .sqlite || ConnectionProfile.isLoopback(profile.host)
    }

    private var statusColor: Color {
        switch status {
        case .online: KTColor.online
        case .connecting: KTColor.accent
        case .offline: KTColor.muted
        }
    }
}
