import KTPluginKit
import SwiftUI

struct SiteWorkersBadge: View {
    let summary: SiteWorkersSummary
    let action: () -> Void

    private var color: Color {
        if summary.crashed > 0 { return Color.KDStatus.error }
        return summary.active > 0 ? Color.KDStatus.running : Color.KDStatus.stopped
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                KTDot(color: color, size: 6)
                Text(summary.label).font(.jbMono(11.5)).foregroundStyle(KTColor.muted).lineLimit(1)
            }
            .fixedSize()
        }
        .buttonStyle(.plain)
        .help("Background workers: open Site Settings")
        .accessibilityLabel(summary.label)
    }
}
