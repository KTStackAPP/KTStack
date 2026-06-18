import SwiftUI
import KDWarmKit

struct DumpEventRow: View {
    let event: DumpEvent
    @State private var expanded = true

    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss.SSS"
        return f
    }()

    var body: some View {
        VStack(alignment: .leading, spacing: KDSpacing.space1) {
            HStack(spacing: KDSpacing.space2) {
                Image(systemName: "arrow.down.circle.fill")
                    .foregroundStyle(Color.KDStatus.info)
                    .font(.system(size: 10))
                Text(event.sourceDisplay)
                    .font(KDFont.mono)
                    .foregroundStyle(.primary)
                Spacer()
                Text(Self.timeFormatter.string(from: event.timestamp))
                    .font(KDFont.footnote)
                    .foregroundStyle(.tertiary)
                Button {
                    withAnimation(.easeInOut(duration: 0.15)) { expanded.toggle() }
                } label: {
                    Image(systemName: expanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 10))
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
            }

            if expanded {
                DumpTreeView(event.root)
                    .padding(.leading, KDSpacing.space4)
            }
        }
        .padding(.vertical, KDSpacing.space2)
        .padding(.horizontal, KDSpacing.space3)
    }
}
