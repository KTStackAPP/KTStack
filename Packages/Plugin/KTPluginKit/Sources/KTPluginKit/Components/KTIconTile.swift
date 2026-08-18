import SwiftUI

public struct KTIconTile<Content: View>: View {
    public let tint: KTTint
    public var size: CGFloat = 38
    public var radius: CGFloat = KTRadius.iconTileSmall
    @ViewBuilder public var content: () -> Content

    public init(
        tint: KTTint,
        size: CGFloat = 38,
        radius: CGFloat = KTRadius.iconTileSmall,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.tint = tint
        self.size = size
        self.radius = radius
        self.content = content
    }

    public var body: some View {
        content()
            .foregroundStyle(tint.fg)
            .frame(width: size, height: size)
            .background(RoundedRectangle(cornerRadius: radius, style: .continuous).fill(tint.bg))
    }
}
