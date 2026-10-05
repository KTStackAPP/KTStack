import KTPlatformContracts
import KTPluginKit
import SwiftUI

struct SiteCompactRow: View, Equatable {
    let site: SiteSummary
    let upstreamRunning: Bool
    let shared: Bool

    var body: some View {
        HStack(spacing: 10) {
            SiteKindIcon(kind: site.kind, size: 28)
            VStack(alignment: .leading, spacing: 1) {
                Text(site.name).font(KTType.label).foregroundStyle(KTColor.ink).lineLimit(1)
                Text(site.domain).font(KTType.caption).foregroundStyle(KTColor.muted).lineLimit(1)
            }
            Spacer(minLength: 8)
            Text(runtimeLabel)
                .font(.jbMono(11.5))
                .foregroundStyle(KTColor.ink3)
                .lineLimit(1)
            shareSlot.frame(width: 14)
            Image(systemName: site.secure ? "lock.fill" : "lock.open")
                .font(.system(size: 11))
                .foregroundStyle(site.secure ? KTColor.online : KTColor.faint)
                .frame(width: 14)
                .accessibilityLabel(site.secure ? "HTTPS" : "HTTP only")
            liveSlot.frame(width: 14)
        }
        .frame(height: 44)
    }

    @ViewBuilder
    private var shareSlot: some View {
        if shared {
            Image(systemName: "dot.radiowaves.left.and.right")
                .font(.system(size: 11))
                .foregroundStyle(KTColor.accent)
                .accessibilityLabel("Shared")
        } else {
            Color.clear
        }
    }

    @ViewBuilder
    private var liveSlot: some View {
        if site.kind == .node || site.kind == .proxy {
            KTDot(color: upstreamRunning ? KTColor.runDot : KTColor.stopDot)
                .accessibilityLabel(upstreamRunning ? "Reachable" : "Not reachable")
        } else {
            Color.clear
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
