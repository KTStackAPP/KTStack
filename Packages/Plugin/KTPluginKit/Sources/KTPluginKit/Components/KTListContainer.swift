import SwiftUI

public struct KTListContainer<Content: View>: View {
    @ViewBuilder public var content: () -> Content

    public init(@ViewBuilder content: @escaping () -> Content) {
        self.content = content
    }

    public var body: some View {
        content()
            .background(RoundedRectangle(cornerRadius: KTRadius.card, style: .continuous).fill(.white))
            .clipShape(RoundedRectangle(cornerRadius: KTRadius.card, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: KTRadius.card, style: .continuous).strokeBorder(KTColor.sep, lineWidth: 1))
            .compositingGroup()
            .padding(1)
    }
}
