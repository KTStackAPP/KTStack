import SwiftUI
import KTStackKit

struct KTBreadcrumbBar: View {
    let trail: [String]
    let onBack: () -> Void

    var body: some View {
        HStack(spacing: 6) {
            ForEach(Array(trail.enumerated()), id: \.offset) { index, name in
                let isCurrent = index == trail.count - 1
                if index > 0 {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 9))
                        .foregroundStyle(KTEditorTheme.faint)
                }
                Text(name)
                    .font(isCurrent ? .system(size: 12, weight: .medium) : .system(size: 12))
                    .foregroundStyle(isCurrent ? KTEditorTheme.label : KTEditorTheme.accent)
                    .lineLimit(1)
                    .onTapGesture { if !isCurrent { onBack() } }
            }
            Spacer()
        }
        .padding(.horizontal, 16).padding(.vertical, 7)
        .background(KTEditorTheme.accentSoft)
    }
}
