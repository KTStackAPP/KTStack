import SwiftUI
import KTStackKit

private struct KTTooltipModifier: ViewModifier {
    let text: String
    let delay: Double

    @State private var hovering = false
    @State private var visible = false

    func body(content: Content) -> some View {
        content
            .onHover { inside in
                hovering = inside
                if inside {
                    DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                        if hovering { visible = true }
                    }
                } else {
                    visible = false
                }
            }
            .popover(isPresented: $visible, arrowEdge: .top) {
                Text(text)
                    .font(.jbMono(11.5))
                    .foregroundStyle(KTColor.ink)
                    .lineLimit(1)
                    .fixedSize()
                    .padding(.horizontal, 11).padding(.vertical, 7)
            }
    }
}

extension View {
    func ktTip(_ text: String, delay: Double = 0.35) -> some View {
        modifier(KTTooltipModifier(text: text, delay: delay))
    }
}
