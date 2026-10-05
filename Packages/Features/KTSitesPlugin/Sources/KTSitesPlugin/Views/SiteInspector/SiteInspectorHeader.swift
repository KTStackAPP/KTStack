import KTPlatformContracts
import KTPluginKit
import SwiftUI

struct SiteInspectorHeader: View {
    let site: SiteSummary
    let framework: PHPFramework
    let canOpen: Bool
    let editors: CodeEditorCatalog
    let preferredEditor: CodeEditor?
    let onOpenLogs: () -> Void
    let onRecheckType: () -> Void
    let onRemove: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                SiteKindIcon(kind: site.kind, size: 36)
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(site.name).font(KTType.label).foregroundStyle(KTColor.ink).lineLimit(1)
                        KTBadge(text: badgeText, tint: badgeTint, radius: 8)
                    }
                    Text(url)
                        .font(KTType.caption)
                        .foregroundStyle(KTColor.muted)
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .textSelection(.enabled)
                }
            }
            HStack(spacing: 6) {
                KTButton(title: "Open", kind: .primary) { SiteActions.openInBrowser(site) }
                    .disabled(!canOpen)
                    .ktTip(openTip)
                if !site.path.isEmpty {
                    SiteQuickEditorButton(site: site, catalog: editors, preferred: preferredEditor)
                    iconButton("folder", "Show in Finder") { SiteActions.revealInFinder(site) }
                    iconButton("terminal", "Open in Terminal") { SiteActions.openTerminal(site) }
                }
                Spacer(minLength: 0)
                moreMenu
            }
        }
        .padding(18)
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
            if !site.path.isEmpty {
                Button("Re-detect Site Type", action: onRecheckType)
            }
            Divider()
            Button("Remove Site…", role: .destructive, action: onRemove)
        } label: {
            Image(systemName: "ellipsis.circle")
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
        .accessibilityLabel("More actions")
    }

    private func iconButton(_ symbol: String, _ label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 13))
                .foregroundStyle(KTColor.ink2)
                .frame(width: 30, height: 28)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .ktTip(label)
        .accessibilityLabel(label)
    }
}
