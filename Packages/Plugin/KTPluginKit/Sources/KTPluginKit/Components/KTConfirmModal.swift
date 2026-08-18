import SwiftUI

public struct KTConfirmModal: View {
    public let title: String
    public let message: String
    public var okLabel: String = "Confirm"
    public var danger: Bool = true
    public let onCancel: () -> Void
    public let onConfirm: () -> Void

    public init(
        title: String,
        message: String,
        okLabel: String = "Confirm",
        danger: Bool = true,
        onCancel: @escaping () -> Void,
        onConfirm: @escaping () -> Void
    ) {
        self.title = title
        self.message = message
        self.okLabel = okLabel
        self.danger = danger
        self.onCancel = onCancel
        self.onConfirm = onConfirm
    }

    private var tint: KTTint {
        danger ? KTTint(fg: KTColor.danger, bg: KTColor.dangerBg)
            : KTTint(fg: KTColor.online, bg: KTColor.onlineBg)
    }

    public var body: some View {
        ZStack {
            KTColor.modalScrim.ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture(perform: onCancel)
            card
        }
    }

    private var card: some View {
        VStack(spacing: 0) {
            KTIconTile(tint: tint, size: 52, radius: 14) {
                Image(systemName: danger ? "trash" : "arrow.clockwise").font(.system(size: 22, weight: .medium))
            }
            Text(title)
                .font(.jbMono(18, .bold)).foregroundStyle(KTColor.ink)
                .padding(.top, 16)
            Text(message)
                .font(.jbMono(13.5)).foregroundStyle(Color(hex: 0x8E8E93))
                .multilineTextAlignment(.center).lineSpacing(2)
                .padding(.top, 7)
            HStack(spacing: 10) {
                Button(action: onCancel) {
                    Text("Cancel").font(.jbMono(14, .medium)).foregroundStyle(KTColor.ink)
                        .frame(maxWidth: .infinity).padding(.vertical, 11)
                        .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Color.white))
                        .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).stroke(KTColor.btnBorder, lineWidth: 0.5))
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                Button(action: onConfirm) {
                    Text(okLabel).font(.jbMono(14, .regular)).foregroundStyle(.white)
                        .frame(maxWidth: .infinity).padding(.vertical, 11)
                        .background(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(danger ? AnyShapeStyle(KTColor.danger) : AnyShapeStyle(KTColor.accentGradient))
                        )
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            .padding(.top, 22)
        }
        .padding(24)
        .frame(width: 400)
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Color.white))
        .background(escCatcher)
    }

    private var escCatcher: some View {
        Button(action: onCancel) { Color.clear }
            .keyboardShortcut(.cancelAction).opacity(0).frame(width: 0, height: 0).accessibilityHidden(true)
    }
}
