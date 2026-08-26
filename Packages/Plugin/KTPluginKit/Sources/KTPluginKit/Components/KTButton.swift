import SwiftUI

public enum KTButtonKind {
    case primary, secondary, danger, link
}

public struct KTButton: View {
    public let title: String
    public var systemImage: String?
    public var kind: KTButtonKind = .secondary
    public var isLoading: Bool = false
    public let action: () -> Void

    @State private var hovering = false

    public init(
        title: String,
        systemImage: String? = nil,
        kind: KTButtonKind = .secondary,
        isLoading: Bool = false,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.systemImage = systemImage
        self.kind = kind
        self.isLoading = isLoading
        self.action = action
    }

    public var body: some View {
        Button(action: { if !isLoading { action() } }) {
            HStack(spacing: 7) {
                if isLoading {
                    ProgressView()
                        .controlSize(.small)
                        .scaleEffect(0.7)
                        .frame(width: 13, height: 13)
                        .tint(foreground)
                } else if let systemImage {
                    Image(systemName: systemImage)
                        .font(.system(size: 12.5, weight: .regular))
                }
                Text(title).font(.jbMono(12.5, weight)).underline(hovering && kind == .link)
            }
            .foregroundStyle(foreground)
            .padding(.vertical, kind == .link ? 2 : (kind == .primary ? 8 : 7))
            .padding(.horizontal, kind == .link ? 2 : 13)
            .background(background)
            .overlay(border)
            .clipShape(RoundedRectangle(cornerRadius: KTRadius.button, style: .continuous))
            .brightness(hovering && kind == .primary ? 0.04 : 0)
            .opacity(isLoading ? 0.7 : 1)
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
    }

    private var weight: Font.Weight {
        kind == .secondary || kind == .link ? .medium : .regular
    }

    private var foreground: Color {
        switch kind {
        case .primary: .white
        case .secondary: KTColor.ink
        case .danger: KTColor.danger
        case .link: KTColor.accent
        }
    }

    @ViewBuilder private var background: some View {
        switch kind {
        case .primary: KTColor.accentGradient
        case .secondary: hovering ? KTColor.btnHover : Color.white
        case .danger: hovering ? KTColor.dangerBg : Color.white
        case .link: Color.clear
        }
    }

    @ViewBuilder private var border: some View {
        switch kind {
        case .primary, .link: EmptyView()
        case .secondary:
            RoundedRectangle(cornerRadius: KTRadius.button, style: .continuous)
                .strokeBorder(KTColor.btnBorder, lineWidth: 0.5)
        case .danger:
            RoundedRectangle(cornerRadius: KTRadius.button, style: .continuous)
                .strokeBorder(KTColor.dangerBorder, lineWidth: 0.5)
        }
    }
}
