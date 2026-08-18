import SwiftUI

public struct KTModalCard<Content: View>: View {
    public let icon: String
    public let tint: KTTint
    public let title: String
    public let subtitle: String
    public var width: CGFloat = 680
    public let onClose: () -> Void
    @ViewBuilder public var content: () -> Content

    public init(
        icon: String,
        tint: KTTint,
        title: String,
        subtitle: String,
        width: CGFloat = 680,
        onClose: @escaping () -> Void,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.icon = icon
        self.tint = tint
        self.title = title
        self.subtitle = subtitle
        self.width = width
        self.onClose = onClose
        self.content = content
    }

    public var body: some View {
        ZStack {
            KTColor.modalScrim
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture(perform: onClose)
            card
        }
    }

    private var card: some View {
        VStack(spacing: 0) {
            header
            content()
        }
        .frame(width: width)
        .background(RoundedRectangle(cornerRadius: KTRadius.modal, style: .continuous).fill(.white))
        .clipShape(RoundedRectangle(cornerRadius: KTRadius.modal, style: .continuous))
        .overlay(alignment: .topTrailing) { closeButton }
        .background(escCatcher)
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 14) {
            KTIconTile(tint: tint, size: 46, radius: 13) {
                Image(systemName: icon).font(.system(size: 21, weight: .medium))
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(KTType.modalTitle).foregroundStyle(KTColor.ink)
                Text(subtitle).font(.jbMono(13.5)).foregroundStyle(Color(hex: 0x8E8E93))
            }
            Spacer(minLength: 30)
        }
        .padding(22)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(LinearGradient(colors: [Color(hex: 0xFBFBFD), .white], startPoint: .top, endPoint: .bottom))
        .overlay(alignment: .bottom) { Rectangle().fill(Color(hex: 0xF0F0F3)).frame(height: 0.5) }
    }

    private var closeButton: some View {
        Button(action: onClose) {
            Image(systemName: "xmark")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(KTColor.muted)
                .frame(width: 30, height: 30)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(14)
    }

    private var escCatcher: some View {
        Button(action: onClose) { Color.clear }
            .keyboardShortcut(.cancelAction)
            .opacity(0)
            .frame(width: 0, height: 0)
            .accessibilityHidden(true)
    }
}
