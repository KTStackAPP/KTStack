import KTPluginKit
import SwiftUI

struct V2ERCanvasToolbar: View {
    @ObservedObject var state: ERDiagramState

    var body: some View {
        HStack(spacing: 8) {
            iconButton("arrow.up.left.and.arrow.down.right") { state.fitToWindow() }
            divider
            iconButton("minus") { state.zoom(to: state.magnification - 0.2) }
            Button { state.zoom(to: 1) } label: {
                Text("\(Int((state.magnification * 100).rounded()))%")
                    .font(.system(size: 11.5, weight: .medium, design: .monospaced).monospacedDigit())
                    .foregroundStyle(Color(nsColor: .labelColor))
                    .frame(minWidth: 40, minHeight: 24)
            }
            .buttonStyle(.plain)
            iconButton("plus") { state.zoom(to: state.magnification + 0.2) }
            divider
            iconButton(
                state.isCompact ? "rectangle.expand.vertical" : "rectangle.compress.vertical",
                active: state.isCompact
            ) { state.setCompact(!state.isCompact) }
            iconButton("arrow.counterclockwise") { state.resetLayout() }
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(.regularMaterial, in: Capsule())
        .overlay(Capsule().stroke(Color(nsColor: .separatorColor), lineWidth: 0.5))
        .shadow(color: .black.opacity(0.12), radius: 4, y: 2)
        .padding(16)
    }

    private var divider: some View {
        Rectangle().fill(Color(nsColor: .separatorColor)).frame(width: 0.5, height: 16)
    }

    private func iconButton(
        _ symbol: String,
        active: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 12, weight: .regular))
                .foregroundStyle(active ? KTEditorTheme.accent : Color(nsColor: .secondaryLabelColor))
                .frame(width: 24, height: 24)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
