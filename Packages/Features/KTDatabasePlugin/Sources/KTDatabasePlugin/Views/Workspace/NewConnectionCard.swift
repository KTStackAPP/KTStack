import KTPluginKit
import SwiftUI

struct NewConnectionCard: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label("New Connection", systemImage: "plus")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
        }
        .buttonStyle(.plain)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(Color(nsColor: .separatorColor), style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
        )
    }
}
