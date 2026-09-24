import KTPluginKit
import KTStackKit
import SwiftUI

struct ShellGlobalCLISection: View {
    let state: GlobalCLILink.State
    let errorText: String?
    let onInstall: () -> Void

    var body: some View {
        Section("Command-Line Tool") {
            switch state {
            case .managed:
                Label("kt is installed in /usr/local/bin", systemImage: "checkmark.circle")
                    .font(KDFont.footnote).foregroundStyle(.secondary)
            case .foreign:
                Label(
                    "/usr/local/bin/kt belongs to another program. KTStack leaves it untouched.",
                    systemImage: "exclamationmark.triangle"
                )
                .font(KDFont.footnote).foregroundStyle(.orange)
            case .absent:
                Button("Install kt Command in /usr/local/bin", action: onInstall)
                Text("Makes kt available in every terminal, even without the shell PATH block.")
                    .font(KDFont.footnote).foregroundStyle(.secondary)
            }

            if let errorText {
                Label(errorText, systemImage: "exclamationmark.triangle.fill")
                    .font(KDFont.footnote).foregroundStyle(.red).textSelection(.enabled)
            }
        }
    }
}
