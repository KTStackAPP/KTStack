import KTPlatformContracts
import KTPluginKit
import SwiftUI

struct SiteKindIcon: View {
    let kind: SiteKind
    var size: CGFloat = 28

    var body: some View {
        let tint = SiteVisuals.tint(for: kind)
        KTIconTile(tint: tint, size: size) {
            if kind == .staticSite {
                Image(systemName: "doc.text")
                    .font(.system(size: size * 0.5, weight: .medium))
                    .foregroundStyle(tint.fg)
            } else {
                KTSiteGlyph(kind: SiteVisuals.kind(for: kind), size: size * 0.5, color: tint.fg)
            }
        }
    }
}
