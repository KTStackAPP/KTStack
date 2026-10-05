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
            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Filter by kind")
    }

    private func chip(_ kind: SiteKind?) -> some View {
        let active = selection == kind
        let title = kind.map(SiteVisuals.label(for:)) ?? "All"
        return Button { selection = kind } label: {
            HStack(spacing: 5) {
                Text(title)
                Text("\(counts[kind] ?? 0)").foregroundStyle(KTColor.faint)
            }
            .font(.jbMono(11.5))
            .foregroundStyle(active ? KTColor.ink : KTColor.ink3)
            .padding(.vertical, 4)
            .padding(.horizontal, 10)
            .background(Capsule().fill(active ? KTColor.cardBg : Color.clear))
            .overlay(Capsule().stroke(active ? KTColor.sep : Color.clear, lineWidth: 0.5))
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(active ? .isSelected : [])
    }
}
