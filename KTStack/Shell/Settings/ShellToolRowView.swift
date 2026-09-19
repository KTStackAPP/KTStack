import KTPluginKit
import KTStackCore
import SwiftUI

struct ShellToolRowView: View {
    let tool: ShellTool
    let isEnabled: Bool
    let isInstalled: Bool
    let onToggle: (Bool) -> Void

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(tool.command)
                        .font(KDFont.body.monospaced())
                        .foregroundStyle(.primary)

                    if !isInstalled {
                        Text("Not Installed")
                            .font(.caption2)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1)
                            .background(Color.orange.opacity(0.15))
                            .foregroundStyle(.orange)
                            .clipShape(Capsule())
                    }
                }

                Text(tool.displayName)
                    .font(KDFont.footnote)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Toggle("", isOn: Binding(
                get: { isEnabled },
                set: { onToggle($0) }
            ))
            .labelsHidden()
            .toggleStyle(.switch)
            .disabled(!isInstalled)
        }
        .padding(.vertical, 2)
    }
}
