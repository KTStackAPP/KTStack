import KTPlatformContracts
import KTPluginKit
import SwiftUI

struct SiteInspectorHeader: View {
    let site: SiteSummary
    let framework: PHPFramework
    let endOfLife: Bool
    let canOpen: Bool
    let editors: CodeEditorCatalog
    let preferredEditor: CodeEditor?
    let onOpenLogs: () -> Void
    let onRecheckType: () -> Void
    let onRemove: () -> Void

    var body: some View {
        HStack(spacing: 14) {
            SiteKindIcon(kind: site.kind, size: 44)
            identity.layoutPriority(-1)
            Spacer(minLength: 8)
            ViewThatFits(in: .horizontal) {
                actions(showsEditorName: true)
                actions(showsEditorName: false)
            }
        }
    }

    private var identity: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                Text(site.name)
                    .font(.jbMono(18, .bold))
                    .foregroundStyle(KTColor.ink)
                    .lineLimit(1)
                KTBadge(text: badgeText, tint: badgeTint, radius: 6)
                if endOfLife {
                    KTBadge(
                        text: "PHP \(site.phpVersion) EOL",
                        tint: KTTint(fg: Color(nsColor: .systemOrange), bg: Color(nsColor: .systemOrange).opacity(0.14)),
                        radius: 6
                    )
                }
            }
            Button { SiteActions.openInBrowser(site) } label: {
                Text(url)
                    .font(.jbMono(12.5))
                    .foregroundStyle(canOpen ? KTColor.accent : KTColor.muted)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            .buttonStyle(.plain)
            .disabled(!canOpen)
            .ktTip(openTip)
        }
    }

    private func actions(showsEditorName: Bool) -> some View {
        HStack(spacing: 6) {
            KTButton(title: "Open", systemImage: "arrow.up.right.square", kind: .primary) { SiteActions.openInBrowser(site) }
                .disabled(!canOpen)
                .ktTip(openTip)
            if hasFolder {
                if let preferredEditor {
                    SiteEditorButton(site: site, catalog: editors, preferred: preferredEditor, showsName: showsEditorName)
                }
                iconButton("folder", "Show in Finder") { SiteActions.revealInFinder(site) }
                iconButton("terminal", "Open in Terminal") { SiteActions.openTerminal(site) }
            }
            moreMenu
        }
        .fixedSize()
    }

    private var hasFolder: Bool {
        !site.path.isEmpty
    }

    private var url: String {
        "\(site.secure ? "https" : "http")://\(site.domain)"
    }

    private var badgeText: String {
        site.kind == .php ? framework.label : SiteVisuals.label(for: site.kind)
    }

    private var badgeTint: KTTint {
        site.kind == .php ? SiteVisuals.tint(for: framework) : SiteVisuals.tint(for: site.kind)
    }

    private var openTip: String {
        if canOpen { return "Open \(site.domain) in your browser" }
        switch site.kind {
        case .node, .proxy: return "Start the server and the upstream to open this site"
        default: return "Start the server to open sites"
        }
    }

    private var moreMenu: some View {
        Menu {
            Button("Open Logs", action: onOpenLogs)
            if hasFolder {
                Button("Re-detect Site Type", action: onRecheckType)
            }
            Divider()
            Button("Remove Site…", role: .destructive, action: onRemove)
        } label: {
            Image(systemName: "ellipsis").font(.system(size: 13))
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .frame(width: 30, height: 30)
        .background(RoundedRectangle(cornerRadius: 7, style: .continuous).fill(KTColor.fieldBg))
        .overlay(RoundedRectangle(cornerRadius: 7, style: .continuous).stroke(KTColor.btnBorder, lineWidth: 1))
        .accessibilityLabel("More actions")
    }

    private func iconButton(_ symbol: String, _ label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 13))
                .foregroundStyle(KTColor.ink)
                .frame(width: 30, height: 30)
                .background(RoundedRectangle(cornerRadius: 7, style: .continuous).fill(KTColor.fieldBg))
                .overlay(RoundedRectangle(cornerRadius: 7, style: .continuous).stroke(KTColor.btnBorder, lineWidth: 1))
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .ktTip(label)
        .accessibilityLabel(label)
    }
}
