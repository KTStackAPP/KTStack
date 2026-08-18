import SwiftUI

public struct KTPill: View {
    public let text: String

    public init(text: String) {
        self.text = text
    }

    public var body: some View {
        Text(text)
            .font(.jbMono(12.5, .regular))
            .foregroundStyle(Color(hex: 0x8E8E93))
            .padding(.vertical, 3)
            .padding(.horizontal, 10)
            .background(Capsule().fill(KTColor.pillBg))
    }
}

public struct KTBadge: View {
    public let text: String
    public let tint: KTTint
    public var radius: CGFloat = 6

    public init(text: String, tint: KTTint, radius: CGFloat = 6) {
        self.text = text
        self.tint = tint
        self.radius = radius
    }

    public var body: some View {
        Text(text)
            .font(.jbMono(11.5, .regular))
            .lineLimit(1)
            .fixedSize(horizontal: true, vertical: false)
            .foregroundStyle(tint.fg)
            .padding(.vertical, 3)
            .padding(.horizontal, 9)
            .background(RoundedRectangle(cornerRadius: radius, style: .continuous).fill(tint.bg))
    }
}
