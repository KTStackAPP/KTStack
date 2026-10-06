import KTPlatformContracts
import KTPluginKit
import SwiftUI

struct SiteCompactRow: View, Equatable {
    let site: SiteSummary
    let upstreamRunning: Bool
    let shared: Bool
    let workers: SiteWorkersSummary
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 10) {
            SiteKindIcon(kind: site.kind, size: 32)
            VStack(alignment: .leading, spacing: 2) {
                Text(site.name).font(.jbMono(13, .semibold)).foregroundStyle(KTColor.ink).lineLimit(1)
                Text(site.domain).font(.jbMono(11.5)).foregroundStyle(KTColor.muted).lineLimit(1)
            }
            Spacer(minLength: 8)
            CappedWidth(max: 138) {
                Text(runtimeLabel)
                    .font(.jbMono(11.5))
                    .foregroundStyle(KTColor.ink2)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(RoundedRectangle(cornerRadius: 5).fill(isSelected ? KTColor.cardBg : Color.primary.opacity(0.06)))
            HStack(spacing: 7) {
                liveDot
                shareIcon
                workersIcon
                Image(systemName: site.secure ? "lock.fill" : "lock.open")
                    .font(.system(size: 11))
                    .foregroundStyle(site.secure ? KTColor.online : KTColor.faint)
                    .frame(width: 12)
                    .accessibilityLabel(site.secure ? "HTTPS" : "HTTP only")
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(isSelected ? KTColor.accentSoft : Color.clear)
        )
    }

    @ViewBuilder
    private var workersIcon: some View {
        if !workers.isEmpty {
            Image(systemName: "gearshape.2")
                .font(.system(size: 11))
                .foregroundStyle(workersColor)
                .help(workers.label)
                .accessibilityLabel(workers.label)
        }
    }

    private var workersColor: Color {
        if workers.failing > 0 { return Color.KDStatus.error }
        return workers.active > 0 ? Color.KDStatus.running : Color.KDStatus.stopped
    }

    @ViewBuilder
    private var shareIcon: some View {
        if shared {
            Image(systemName: "dot.radiowaves.left.and.right")
                .font(.system(size: 11))
                .foregroundStyle(KTColor.accent)
                .accessibilityLabel("Shared")
        }
    }

    @ViewBuilder
    private var liveDot: some View {
        if site.kind == .node || site.kind == .proxy {
            KTDot(color: upstreamRunning ? KTColor.runDot : KTColor.stopDot)
                .accessibilityLabel(upstreamRunning ? "Reachable" : "Not reachable")
        }
    }

    private var runtimeLabel: String {
        switch site.kind {
        case .php:
            return "PHP \(site.phpVersion)"
        case .node:
            if let port = site.nodePort { return "→ :\(port)" }
            return "no port"
        case .proxy:
            let target = site.proxyTarget ?? ""
            for prefix in ["https://", "http://"] where target.hasPrefix(prefix) {
                return "→ " + target.dropFirst(prefix.count)
            }
            return "→ \(target)"
        case .staticSite:
            return "static"
        }
    }
}

// Rộng theo nội dung nhưng không quá max, cắt chữ khi dài.
private struct CappedWidth: Layout {
    let max: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        guard let child = subviews.first else { return .zero }
        let ideal = child.sizeThatFits(.unspecified)
        let width = min(ideal.width, max, proposal.width ?? .infinity)
        return CGSize(width: width, height: child.sizeThatFits(ProposedViewSize(width: width, height: nil)).height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        subviews.first?.place(at: bounds.origin, proposal: ProposedViewSize(bounds.size))
    }
}
