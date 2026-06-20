import SwiftUI
import KTStackKit

struct KTBreadcrumbBar: View {
    let trail: [String]
    let onBack: () -> Void

    var body: some View {
        HStack(spacing: 6) {
            Button(action: onBack) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(KTColor.accent)
                    .frame(width: 22, height: 22)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            ForEach(Array(trail.enumerated()), id: \.offset) { index, name in
                if index > 0 {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 8, weight: .semibold))
                        .foregroundStyle(KTColor.faint)
                }
                Text(name)
                    .font(.jbMono(12, index == trail.count - 1 ? .medium : .regular))
                    .foregroundStyle(index == trail.count - 1 ? KTColor.ink2 : KTColor.muted)
                    .lineLimit(1)
            }
            Spacer()
        }
        .padding(.horizontal, 16).padding(.vertical, 7)
        .background(KTColor.accentSoft)
    }
}
