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

                    if isInstalled {
                        HStack(spacing: 3) {
                            Circle()
                                .fill(Color.green)
                                .frame(width: 6, height: 6)
                            Text("Installed")
                                .font(.caption2.weight(.medium))
                        }
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.green.opacity(0.12))
                        .foregroundStyle(.green)
                        .clipShape(Capsule())
                    } else {
                        HStack(spacing: 3) {
                            Circle()
                                .fill(Color.orange)
                                .frame(width: 6, height: 6)
                            Text("Not Installed")
                                .font(.caption2.weight(.medium))
                        }
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.orange.opacity(0.12))
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
