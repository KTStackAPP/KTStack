import KTPluginKit
import KTStackCore
import SwiftUI

struct ShellSuiteSectionView: View {
    let suite: ShellToolSuite
    let tools: [ShellTool]
    let isSuiteEnabled: Bool
    let isToolEnabled: (String) -> Bool
    let isToolInstalled: (String) -> Bool
    let onToggleSuite: (Bool) -> Void
    let onToggleTool: (String, Bool) -> Void
    @Binding var isExpanded: Bool

    var body: some View {
        DisclosureGroup(isExpanded: $isExpanded) {
            VStack(spacing: 8) {
                ForEach(tools) { tool in
                    ShellToolRowView(
                        tool: tool,
                        isEnabled: isToolEnabled(tool.id),
                        isInstalled: isToolInstalled(tool.id),
                        onToggle: { onToggleTool(tool.id, $0) }
                    )
                }
            }
            .padding(.top, 4)
        } label: {
            HStack(spacing: 8) {
                Image(systemName: suite.iconName)
                    .font(KDFont.subheadline)
                    .foregroundStyle(Color.accentColor)
                    .frame(width: 20)

                Text(suite.displayName)
                    .font(KDFont.headline)

                Spacer()

                Button(action: {
                    onToggleSuite(!isSuiteEnabled)
                }) {
                    Text(isSuiteEnabled ? "Disable All" : "Enable All")
                        .font(.caption)
                        .foregroundStyle(isSuiteEnabled ? .secondary : Color.accentColor)
                }
                .buttonStyle(.plain)
                .padding(.trailing, 4)
            }
        }
    }
}
