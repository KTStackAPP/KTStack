import KTPluginKit
import SwiftUI

/// Hàng kết nối người dùng lưu: badge LOCAL/REMOTE, host mono, nút Open.
struct SavedConnectionRow: View {
    let profile: ConnectionProfile
    let status: ServerStatus
    let isSelected: Bool
    let onOpen: () -> Void

    var body: some View {
        HStack(spacing: KTSpacing.md) {
            ConnectionRowStatus.tile(profile.kind)
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: KTSpacing.sm) {
                    Text(profile.name).font(KTType.rowName).foregroundStyle(KTColor.ink).lineLimit(1)
                    KTBadge(
                        text: isLocal ? "LOCAL" : "REMOTE",
                        tint: isLocal ? KTIconTint.globe : KTIconTint.neutral
                    )
                }
                HStack(spacing: 6) {
                    KTDot(color: ConnectionRowStatus.color(status), size: 7)
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
}
