import SwiftUI
import KTStackKit

struct KTSiteActionsMenu: View {
    let site: Site
    let canOpen: Bool
    let isSharing: Bool
    let onOpenLogs: () -> Void
    let onToggleShare: (Bool) -> Void
    let onRemove: () -> Void
    var onError: (String) -> Void = { _ in }

    var body: some View {
        Menu {
            Button { KTSiteActions.openInBrowser(site) } label: {
                Label("Open in Browser", systemImage: "safari")
            }
            .disabled(!canOpen)
            .keyboardShortcut("o", modifiers: .command)

            Button { KTSiteActions.revealInFinder(site) } label: {
                Label("Reveal in Finder", systemImage: "folder")
            }
            .keyboardShortcut("r", modifiers: [.command, .shift])

            Button { KTSiteActions.openTerminal(site) } label: {
                Label("Open Terminal Here", systemImage: "terminal")
            }
            .keyboardShortcut("t", modifiers: [.command, .option])

            Divider()

            Button(action: onOpenLogs) {
                Label("Logs", systemImage: "text.alignleft")
            }
            .keyboardShortcut("l", modifiers: .command)

            if site.type == .php {
                Button {
                    do { try KTSiteActions.configureVSCode(site) }
                    catch { onError(error.localizedDescription) }
                } label: {
                    Label("Configure VS Code Debug", systemImage: "curlybraces")
                }
            }

            Button { onToggleShare(!isSharing) } label: {
                Label(isSharing ? "Stop Sharing" : "Share via Tunnel",
                      systemImage: isSharing ? "antenna.radiowaves.left.and.right.slash" : "antenna.radiowaves.left.and.right")
            }

            Divider()

            Button(role: .destructive, action: onRemove) {
                Label("Remove Site", systemImage: "trash")
            }
            .keyboardShortcut(.delete, modifiers: .command)
        } label: {
            Image(systemName: "ellipsis")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(KTColor.muted)
                .frame(width: 32, height: 30)
                .contentShape(Rectangle())
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .frame(width: 32)
        .accessibilityLabel("More actions for \(site.name)")
    }
}
