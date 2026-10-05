import SwiftUI

public struct KTListContainer<Content: View>: View {
    @ViewBuilder public var content: () -> Content

    public init(@ViewBuilder content: @escaping () -> Content) {
        self.content = content
    }

    public var body: some View {
        content()
            // No compositingGroup: wrapping a ScrollView flattens the whole scrolling content into an
            // offscreen buffer every frame, which stutters long lists (Sites).
            .ktLiquidGlassCard(cornerRadius: KTRadius.card)
            .padding(1)
    }
}
