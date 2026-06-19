import SwiftUI
import KTStackKit

struct SiteRowStatusBadge: View {
    let isRunning: Bool

    var body: some View {
        HStack(spacing: KDSpacing.space2) {
            Circle()
                .fill(color)
                .frame(width: 7, height: 7)
            Text(title)
                .font(KDFont.footnote)
                .foregroundStyle(.secondary)
        }
        .frame(width: 96, alignment: .leading)
        .accessibilityLabel(title)
    }

    private var title: String {
        isRunning ? "Running" : "Stopped"
    }

    private var color: Color {
        isRunning ? Color.KDStatus.running : Color.KDStatus.stopped.opacity(0.45)
    }
}
