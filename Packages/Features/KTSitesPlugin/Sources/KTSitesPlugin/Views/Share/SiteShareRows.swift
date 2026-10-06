import AppKit
import KTPlatformContracts
import KTPluginKit
import SwiftUI

// Hàng Public URL kèm hàng "Live" khi tunnel đang chạy.
struct SiteShareRows: View {
    let share: SiteShareState?
    let onToggleShare: (Bool) -> Void

    private static let expiryFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "HH:mm"
        return formatter
    }()

    private var starting: Bool { share?.starting ?? false }
    private var publicURL: URL? { share?.publicURL }

    var body: some View {
        InspectorRow("Public URL") {
            if let error = share?.error, publicURL == nil, !starting {
                InspectorHint("Sharing failed: \(error)", color: KTColor.danger)
            } else {
                InspectorHint(starting ? "Starting Cloudflare Tunnel…" : "Share through Cloudflare Tunnel")
            }
        } trailing: {
            HStack(spacing: 8) {
                if starting {
                    ProgressView().controlSize(.small)
                } else {
                    if share?.error != nil, publicURL == nil {
                        InspectorButton(title: "Retry") { onToggleShare(true) }
                    }
                    InspectorSwitch(label: "Share publicly", isOn: publicURL != nil) { onToggleShare(publicURL == nil) }
                }
            }
        }
        if let publicURL {
            liveRow(publicURL)
        }
    }

    private var liveLabel: String {
        guard let expiresAt = share?.expiresAt else { return "Live" }
        return "Live · until \(Self.expiryFormatter.string(from: expiresAt))"
    }

    private func liveRow(_ url: URL) -> some View {
        HStack(spacing: 8) {
            Text(liveLabel)
                .font(.jbMono(12.5))
                .foregroundStyle(KTColor.accent)
                .frame(width: 130, alignment: .leading)
                .ktTip("The tunnel closes automatically at this time")
            Text(url.absoluteString)
                .font(.jbMono(12.5))
                .foregroundStyle(KTColor.ink)
                .lineLimit(1)
                .truncationMode(.middle)
                .textSelection(.enabled)
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(RoundedRectangle(cornerRadius: 6).fill(KTColor.fieldBg))
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(KTColor.btnBorder, lineWidth: 1))
            Button {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(url.absoluteString, forType: .string)
            } label: {
                Image(systemName: "doc.on.doc").font(.system(size: 12))
            }
            .buttonStyle(.borderless)
            .ktTip("Copy tunnel URL")
            .accessibilityLabel("Copy tunnel URL")
            TunnelQRCodeButton(url: url)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .frame(minHeight: 46)
        .background(KTColor.accentSoft)
        .overlay(alignment: .top) { Rectangle().fill(KTColor.hairline).frame(height: 1) }
    }
}
