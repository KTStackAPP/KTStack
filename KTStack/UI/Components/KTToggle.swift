import KTStackKit
import SwiftUI

struct KTToggle: View {
    let isOn: Bool
    let action: () -> Void

    // Knob slides between the 3pt insets on each side: width - knob - 2*inset.
    private var knobTravel: CGFloat { KTMetric.toggleWidth - KTMetric.toggleKnob - 6 }

    var body: some View {
        Button(action: action) {
            Capsule()
                .fill(isOn ? KTColor.accent : Color(hex: 0xE3E3E9))
                .frame(width: KTMetric.toggleWidth, height: KTMetric.toggleHeight)
                .overlay(alignment: .leading) {
                    Circle()
                        .fill(.white)
                        .frame(width: KTMetric.toggleKnob, height: KTMetric.toggleKnob)
                        .shadow(color: .black.opacity(0.28), radius: 1, y: 1)
                        .padding(3)
                        // Animate a transform offset, not the ZStack alignment: alignment-based
                        // animation re-lays-out every frame and visibly stutters.
                        .offset(x: isOn ? knobTravel : 0)
                }
                .animation(.easeInOut(duration: 0.18), value: isOn)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isOn ? [.isButton, .isSelected] : .isButton)
    }
}
