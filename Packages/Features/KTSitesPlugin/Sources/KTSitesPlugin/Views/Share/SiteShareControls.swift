import AppKit
import KTPlatformContracts
import KTPluginKit
import SwiftUI

struct SiteShareControls: View {
    var share: SiteShareState?
    let onToggleShare: (Bool) -> Void

    private var shareStarting: Bool { share?.starting ?? false }
    private var shareURL: URL? { share?.publicURL }
    private var shareExpiresAt: Date? { share?.expiresAt }

    private static let expiryFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "HH:mm"
        return formatter
    }()

    var body: some View {
        HStack(spacing: 2) {
            if shareStarting {
                ProgressView().controlSize(.small).frame(width: 28, height: 26)
            } else if let shareURL {
                if let shareExpiresAt {
                    Text("Expires \(Self.expiryFormatter.string(from: shareExpiresAt))")
                        .font(.jbMono(11))
                        .foregroundStyle(KTColor.ink2)
                        .ktTip("Tunnel closes automatically at this time")
                        .padding(.trailing, 4)
                }
                iconButton("doc.on.doc", help: "Copy tunnel URL", tint: KTColor.ink2) {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(shareURL.absoluteString, forType: .string)
                }
                TunnelQRCodeButton(url: shareURL).foregroundStyle(KTColor.accent)
                iconButton(
                    "antenna.radiowaves.left.and.right",
                    help: "Stop sharing via tunnel",
                    tint: KTColor.accent
                ) { onToggleShare(false) }
            } else if let error = share?.error {
                iconButton(
                    "exclamationmark.triangle.fill",
                    help: "Sharing failed: \(error) Click to try again.",
                    tint: KTColor.danger
                ) { onToggleShare(true) }
                .accessibilityLabel("Sharing failed: \(error)")
            } else {
                iconButton(
                    "antenna.radiowaves.left.and.right.slash",
                    help: "Share via tunnel",
                    tint: KTColor.ink2
                ) { onToggleShare(true) }
            }
        }
    }

    private func iconButton(
        _ symbol: String,
        help: String,
        tint: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(tint)
                .frame(width: 28, height: 26)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .ktTip(help)
    }
}
