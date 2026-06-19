import SwiftUI
import AppKit
import KTStackKit

struct SiteShareControlView: View {
    let shareStatus: TunnelStatus
    let onToggleShare: (Bool) -> Void

    @State private var didCopy = false

    var body: some View {
        switch shareStatus {
        case .idle, .expired:
            Button { onToggleShare(true) } label: {
                Image(systemName: "antenna.radiowaves.left.and.right")
            }
            .buttonStyle(.borderless)
            .help(shareStatus == .expired ? "Tunnel expired — share again" : "Share via public tunnel")
            .accessibilityLabel(shareStatus == .expired ? "Share expired tunnel again" : "Share via public tunnel")
        case .starting:
            ProgressView().controlSize(.small)
        case .active(let url):
            activeControls(url: url, unverified: false)
        case .activeUnverified(let url):
            activeControls(url: url, unverified: true)
        case .error(let message):
            HStack(spacing: 4) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(Color.KDStatus.error)
                Text(message)
                    .font(KDFont.footnote)
                    .foregroundStyle(Color.KDStatus.error)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .help(message)
                Button { onToggleShare(true) } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .buttonStyle(.borderless)
                .help("Share again")
            }
        }
    }

    private func activeControls(url: URL, unverified: Bool) -> some View {
        HStack(spacing: 4) {
            if unverified {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(Color.KDStatus.warning)
                    .help("Couldn't verify the link from this machine (restricted network). Test it from another network — it may still work for visitors.")
            } else {
                Image(systemName: "dot.radiowaves.left.and.right")
                    .foregroundStyle(Color.KDStatus.warning)
            }
            Text(url.host ?? url.absoluteString)
                .font(KDFont.footnote)
                .lineLimit(1)
                .truncationMode(.middle)
                .help(url.absoluteString)
            Button { copy(url) } label: {
                Image(systemName: didCopy ? "checkmark" : "doc.on.doc")
            }
            .buttonStyle(.borderless)
            .help("Copy public URL")
            .accessibilityLabel(didCopy ? "Public URL copied" : "Copy public URL")
            TunnelQRCodeButton(url: url)
            Button { onToggleShare(false) } label: {
                Image(systemName: "stop.circle")
            }
            .buttonStyle(.borderless)
            .help("Stop sharing")
            .accessibilityLabel("Stop sharing public tunnel")
        }
    }

    private func copy(_ url: URL) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(url.absoluteString, forType: .string)
        didCopy = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { didCopy = false }
    }
}
