import KTPlatformContracts
import KTPluginKit
import SwiftUI

enum EngineVersionState {
    case active, installed, available
}

struct EngineVersionRow: View {
    let engine: ServiceEngine
    let version: String
    let isActive: Bool
    let isRunning: Bool
    let isBusy: Bool
    let meta: String
    let blockReason: String?
    let isExpanded: Bool
    let onSetActive: () -> Void
    let onToggleRunning: () -> Void
    let onToggleInspector: () -> Void

    @State private var hovering = false

    var body: some View {
        HStack(spacing: 14) {
            KTIconTile(tint: engine.tint, size: 44, radius: 11) {
                Image(systemName: engine.symbolName).font(.system(size: 20, weight: .medium))
            }
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 8) {
                    Text("\(engine.displayName) \(version)").font(.jbMono(14, .semibold)).foregroundStyle(KTColor.ink)
                    if isActive {
                        KTBadge(text: "Active", tint: KTTint(fg: .white, bg: KTColor.accent), radius: 20)
                        if isRunning {
                            KTBadge(text: "Running", tint: KTTint(fg: KTColor.online, bg: KTColor.onlineBg), radius: 20)
                        }
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
            if isActive { Rectangle().fill(KTColor.accent).frame(width: 3) }
        }
        .onHover { hovering = $0 }
    }

    @ViewBuilder
    private var background: some View {
        if isActive {
            KTColor.accentBand
        } else if hovering {
            KTColor.rowHover
        } else {
            Color.clear
        }
    }

    @ViewBuilder
    private var trailing: some View {
        HStack(spacing: 10) {
            if isActive {
                if isBusy { ProgressView().controlSize(.small) }
                KTToggle(isOn: isRunning) { if !isBusy { onToggleRunning() } }
                    .opacity(isBusy ? 0.5 : 1)
                    .allowsHitTesting(!isBusy)
            } else {
                KTButton(title: "Set active", kind: .link, action: onSetActive)
                    .disabled(blockReason != nil)
                    .opacity(blockReason != nil ? 0.4 : 1)
                    .help(blockReason ?? "")
            }
            gearButton
        }
    }

    private var gearButton: some View {
        Button(action: onToggleInspector) {
            Image(systemName: "gearshape").font(.system(size: 15, weight: .regular))
                .foregroundStyle(isExpanded ? KTColor.accent : KTColor.muted)
                .frame(width: 28, height: 30).contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help("Configure \(engine.displayName) \(version)")
    }
}

#if DEBUG
    #Preview {
        VStack(spacing: 0) {
            EngineVersionRow(
                engine: .mysql, version: "8.4", isActive: true, isRunning: true, isBusy: false,
                meta: "Running · data stored per version", blockReason: nil, isExpanded: false,
                onSetActive: {}, onToggleRunning: {}, onToggleInspector: {}
            )
            EngineVersionRow(
                engine: .mysql, version: "8.0", isActive: false, isRunning: false, isBusy: false,
                meta: "Stop MySQL 8.4 to switch", blockReason: "Stop MySQL 8.4 to switch", isExpanded: false,
                onSetActive: {}, onToggleRunning: {}, onToggleInspector: {}
            )
        }
        .frame(width: 640)
    }
#endif
