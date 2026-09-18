import SwiftUI

public struct KTLiquidGlassCardModifier: ViewModifier {
    public let cornerRadius: CGFloat

    public init(cornerRadius: CGFloat = KTRadius.card) {
        self.cornerRadius = cornerRadius
    }

    public func body(content: Content) -> some View {
        if #available(macOS 27, *) {
            content
                .glassEffect(.regular, in: .rect(cornerRadius: cornerRadius))
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .strokeBorder(KTColor.sepFaint, lineWidth: 0.5)
                )
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        } else {
            content
                .background(
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(KTColor.cardBg)
                )
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .strokeBorder(KTColor.sep, lineWidth: 0.5)
                )
        }
    }
}

public struct KTLiquidGlassInteractiveModifier: ViewModifier {
    public let cornerRadius: CGFloat
    public let tint: Color?

    public init(cornerRadius: CGFloat = KTRadius.button, tint: Color? = nil) {
        self.cornerRadius = cornerRadius
        self.tint = tint
    }

    public func body(content: Content) -> some View {
        if #available(macOS 27, *) {
            if let tint {
                content
                    .glassEffect(.regular.tint(tint).interactive(), in: .rect(cornerRadius: cornerRadius))
                    .overlay(
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .strokeBorder(tint.opacity(0.3), lineWidth: 0.5)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            } else {
                content
                    .glassEffect(.regular.interactive(), in: .rect(cornerRadius: cornerRadius))
                    .overlay(
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .strokeBorder(KTColor.sepFaint, lineWidth: 0.5)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            }
        } else {
            content
                .background(
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(tint?.opacity(0.12) ?? KTColor.cardBg)
                )
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .strokeBorder(tint?.opacity(0.3) ?? KTColor.sep, lineWidth: 0.5)
                )
        }
    }
}

public extension View {
    func ktLiquidGlassCard(cornerRadius: CGFloat = KTRadius.card) -> some View {
        modifier(KTLiquidGlassCardModifier(cornerRadius: cornerRadius))
    }

    func ktLiquidGlassInteractive(cornerRadius: CGFloat = KTRadius.button, tint: Color? = nil) -> some View {
        modifier(KTLiquidGlassInteractiveModifier(cornerRadius: cornerRadius, tint: tint))
    }
}
