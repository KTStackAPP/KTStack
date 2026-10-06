import KTPlatformContracts
import KTPluginKit
import SwiftUI

struct SitesKindChips: View {
    @Binding var selection: SiteKind?
    let counts: [SiteKind?: Int]

    private static let order: [SiteKind?] = [nil, .php, .staticSite, .node, .proxy]

    var body: some View {
        HStack(spacing: 6) {
            ForEach(Self.order, id: \.self) { kind in
                chip(kind)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Filter by kind")
    }

    private func chip(_ kind: SiteKind?) -> some View {
        let active = selection == kind
        let title = kind.map(SiteVisuals.label(for:)) ?? "All"
        return Button { selection = kind } label: {
            HStack(spacing: 6) {
                Text(title)
                Text("\(counts[kind] ?? 0)").foregroundStyle(active ? KTColor.contentBg.opacity(0.7) : KTColor.muted)
            }
            .font(.jbMono(12))
            .foregroundStyle(active ? KTColor.contentBg : KTColor.ink)
            .padding(.vertical, 5)
            .padding(.horizontal, 11)
            .background(Capsule().fill(active ? KTColor.ink : KTColor.fieldBg))
            .overlay(Capsule().stroke(active ? KTColor.ink : KTColor.sep, lineWidth: 1))
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(active ? .isSelected : [])
    }
}
