import SwiftUI
import KTStackKit

struct SiteRowOverflowMenu: View {
    let siteName: String
    let type: SiteType
    let canOpen: Bool
    let onOpen: () -> Void
    let onRevealInFinder: () -> Void
    let onOpenTerminal: () -> Void
    let onOpenLogs: () -> Void
    let onConfigureVSCode: () -> Void
    let onRemove: () -> Void

    var body: some View {
        Menu {
            Button(action: onOpen) {
                Label("Open in Browser", systemImage: "safari")
            }
            .disabled(!canOpen)

            Button(action: onRevealInFinder) {
                Label("Reveal in Finder", systemImage: "folder")
            }

            Button(action: onOpenTerminal) {
                Label("Open Terminal Here", systemImage: "terminal")
            }

            Button(action: onOpenLogs) {
                Label("Logs", systemImage: "text.alignleft")
            }

            if type == .php {
                Button(action: onConfigureVSCode) {
                    Label("Configure VS Code Debug", systemImage: "curlybraces")
                }
            }

            Divider()

            Button(role: .destructive, action: onRemove) {
                Label("Remove Site", systemImage: "trash")
            }
        } label: {
            Label("More actions", systemImage: "ellipsis")
                .labelStyle(.iconOnly)
                .frame(width: 28, height: 28)
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .frame(width: 32)
        .help("More actions")
        .accessibilityLabel("More actions for \(siteName)")
    }
}
