import SwiftUI

public struct KTListContainer<Content: View>: View {
    @ViewBuilder public var content: () -> Content

    public init(@ViewBuilder content: @escaping () -> Content) {
        self.content = content
    }

    public var body: some View {
        content()
            .ktLiquidGlassCard(cornerRadius: KTRadius.card)
            .compositingGroup()
            .padding(1)
    }
}
