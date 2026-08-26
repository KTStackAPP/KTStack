import KTPluginKit
import KTStackCore
import SwiftUI

struct RuntimeVersionRow: View {
    let language: RuntimeLanguage
    let version: String
    let isDefault: Bool
    let isEndOfLife: Bool
    let xdebugOn: Bool
    let meta: String
    let isExpanded: Bool
    let onSetDefault: () -> Void
    let onToggleInspector: () -> Void

    @State private var hovering = false

    var body: some View {
        HStack(spacing: 14) {
            KTIconTile(tint: language == .php ? KTIconTint.php : KTIconTint.cube, size: 44, radius: 11) {
                Image(systemName: language.symbolName).font(.system(size: 20, weight: .medium))
            }
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 8) {
                    Text(label).font(.jbMono(14, .semibold)).foregroundStyle(KTColor.ink)
                    if isDefault {
                        KTBadge(text: "Default", tint: KTTint(fg: .white, bg: KTColor.accent), radius: 20)
                    }
                    if isEndOfLife {
                        KTBadge(text: "EOL", tint: KTTint(fg: KTColor.danger, bg: KTColor.dangerBg), radius: 20)
                    }
                    if xdebugOn {
                        KTBadge(text: "Xdebug", tint: KTIconTint.cube, radius: 20)
                    }
                }
                Text(meta).font(KTType.sub).foregroundStyle(KTColor.ink3)
            }
            Spacer(minLength: 8)
            trailing
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 18)
        .frame(minHeight: 56)
        .background(background)
        .overlay(alignment: .leading) {
            if isDefault { Rectangle().fill(KTColor.accent).frame(width: 3) }
        }
        .onHover { hovering = $0 }
    }

    @ViewBuilder
    private var background: some View {
        if isDefault {
            KTColor.accentBand
        } else if hovering {
            KTColor.rowHover
        } else {
            Color.clear
        }
    }

    private var trailing: some View {
        HStack(spacing: 10) {
            if !isDefault {
                KTButton(title: "Set as default", kind: .link, action: onSetDefault)
            }
            Button(action: onToggleInspector) {
                Image(systemName: "gearshape").font(.system(size: 15, weight: .regular))
                    .foregroundStyle(isExpanded ? KTColor.accent : KTColor.muted)
                    .frame(width: 28, height: 30).contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help("Configure \(label)")
        }
    }

    private var label: String {
        "\(language == .php ? "PHP" : "Node") \(version)"
    }
}

#if DEBUG
    #Preview {
        VStack(spacing: 0) {
            RuntimeVersionRow(
                language: .php, version: "8.5", isDefault: true, isEndOfLife: false, xdebugOn: true,
                meta: "Default for new sites and terminals · 3 sites", isExpanded: false,
                onSetDefault: {}, onToggleInspector: {}
            )
            RuntimeVersionRow(
                language: .php, version: "7.4", isDefault: false, isEndOfLife: true, xdebugOn: false,
                meta: "2 sites · no security updates", isExpanded: false,
                onSetDefault: {}, onToggleInspector: {}
            )
        }
        .frame(width: 640)
    }
#endif
