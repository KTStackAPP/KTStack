import KTPlatformContracts
import KTPluginKit
import KTStackCore
import SwiftUI

struct SiteGridCard: View {
    let site: SiteSummary
    let availableVersions: [String]
    let canOpen: Bool
    let isSharing: Bool
    var shareStarting: Bool = false
    var shareURL: URL?
    var shareExpiresAt: Date?
    let apacheInstalled: Bool
    let apacheInstalling: Bool
    let framework: PHPFramework
    let onOpen: () -> Void
    let onSetVersion: (String) -> Void
    let onSetSecure: (Bool) -> Void
    let onSetEngine: (SiteServerEngine) -> Void
    let onInstallApache: () -> Void
    let onOpenLogs: () -> Void
    let onToggleShare: (Bool) -> Void
    let onRemove: () -> Void
    var onConfigureVSCode: () -> Void = {}
    var onRestore: () -> Void = {}
    var onSettings: () -> Void = {}

    private var proxyDisplay: String? {
        guard let raw = site.proxyTarget else { return nil }
        if case let .success(target) = ProxyTarget.parse(raw) { return target.displayString }
        return raw
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top) {
                KTIconTile(tint: SiteVisuals.tint(for: site.kind), size: 42, radius: KTRadius.iconTile) {
                    KTSiteGlyph(
                        kind: SiteVisuals.kind(for: site.kind),
                        size: 21,
                        color: SiteVisuals.tint(for: site.kind).fg
                    )
                }
                Spacer()
                KTToggle(isOn: site.secure, action: { onSetSecure(!site.secure) })
                    .help("Serve over HTTPS")
            }
            Text(site.name).font(KTType.cardName).foregroundStyle(KTColor.ink).lineLimit(1)
                .padding(.top, 13)
            Text(site.domain).font(KTType.sub).foregroundStyle(KTColor.muted).lineLimit(1)
            if site.kind == .proxy, let target = proxyDisplay {
                Text("→ \(target)").font(.jbMono(12)).foregroundStyle(KTColor.faint).lineLimit(1)
            }

            HStack(spacing: 7) {
                KTStatusLabel(running: canOpen)
                Spacer()
                if site.kind == .php {
                    KTBadge(text: framework.label, tint: SiteVisuals.tint(for: framework), radius: 7)
                } else {
                    KTBadge(text: SiteVisuals.label(for: site.kind), tint: SiteVisuals.tint(for: site.kind), radius: 7)
                }
            }
            .padding(.top, 13)

            // The two runtime menus are fixedSize; on a narrow grid card they cannot share a row with
            // the status label without squeezing the badge into a vertical strip, so give them their own row.
            if site.kind == .php {
                HStack(spacing: 7) {
                    PhpMenu(current: site.phpVersion, versions: availableVersions, onSelect: onSetVersion)
                    EngineMenu(
                        current: site.engine,
                        port: site.backendPort,
                        apacheInstalled: apacheInstalled,
                        apacheInstalling: apacheInstalling,
                        onSelect: onSetEngine,
                        onInstallApache: onInstallApache
                    )
                    Spacer()
                }
                .padding(.top, 8)
            }

            HStack(spacing: 8) {
                KTButton(title: "Open", kind: .secondary, action: onOpen)
                    .disabled(!canOpen)
                    .frame(maxWidth: .infinity)
                SiteShareControls(
                    shareStarting: shareStarting,
                    shareURL: shareURL,
                    shareExpiresAt: shareExpiresAt,
                    onToggleShare: onToggleShare
                )
                SiteActionsMenu(
                    site: site,
                    canOpen: canOpen,
                    onOpenLogs: onOpenLogs,
                    onRemove: onRemove,
                    onConfigureVSCode: onConfigureVSCode,
                    onRestore: onRestore,
                    onSettings: onSettings
                )
            }
            .padding(.top, 14)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: KTRadius.cardLarge, style: .continuous)
                .fill(.white)
                .overlay(
                    RoundedRectangle(cornerRadius: KTRadius.cardLarge, style: .continuous)
                        .strokeBorder(KTColor.sep, lineWidth: 1)
                )
        )
        .compositingGroup()
    }
}
