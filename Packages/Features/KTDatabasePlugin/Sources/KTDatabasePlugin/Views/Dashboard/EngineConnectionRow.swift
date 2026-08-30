import KTPlatformContracts
import KTPluginKit
import SwiftUI

/// Hàng engine managed: trạng thái reachability + Install/Start/Open như tab cũ.
struct EngineConnectionRow: View {
    let profile: ConnectionProfile
    let status: ServerStatus
    let installed: Bool
    let isSelected: Bool
    let onInstall: () -> Void
    let onStart: () -> Void
    let onOpen: () -> Void

    var body: some View {
        HStack(spacing: KTSpacing.md) {
            ConnectionRowStatus.tile(profile.kind)
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: KTSpacing.sm) {
                    Text(ConnectionRowStatus.engineLabel(profile.kind))
                        .font(KTType.rowName).foregroundStyle(KTColor.ink)
                    Text("bundled").font(KTType.sub).foregroundStyle(KTColor.muted)
                }
                HStack(spacing: 6) {
                    KTDot(color: ConnectionRowStatus.color(status), size: 7)
                    Text(statusText)
                        .font(KTType.sub)
                        .foregroundStyle(ConnectionRowStatus.color(status))
                }
            }
            Spacer(minLength: KTSpacing.sm)
            if !installed {
                KTButton(title: "Install", systemImage: "arrow.down.circle", action: onInstall)
            } else if status != .online {
                KTButton(title: "Start", systemImage: "play.fill", action: onStart)
            }
            KTButton(title: "Open", kind: .primary, action: onOpen)
                .disabled(!installed)
                .keyboardShortcut(isSelected && installed ? .defaultAction : nil)
        }
        .padding(.vertical, KTSpacing.sm)
    }

    private var statusText: String {
        ConnectionRowStatus.engineText(
            status: status, installed: installed, host: "\(profile.host):\(profile.port)"
        )
    }
}
