import SwiftUI

public struct KTEngineCard: View {
    public let name: String
    public let tint: KTTint
    public let active: Bool
    public var action: () -> Void

    @State private var hovering = false

    public init(name: String, tint: KTTint, active: Bool, action: @escaping () -> Void) {
        self.name = name
        self.tint = tint
        self.active = active
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            HStack(spacing: 9) {
                KTIconTile(tint: tint, size: 30, radius: 8) {
                    Image(systemName: "cylinder.split.1x2").font(.system(size: 14, weight: .medium))
                }
                Text(name)
                    .font(.jbMono(13, .regular))
                    .foregroundStyle(KTColor.ink)
                    .lineLimit(1)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 11).padding(.vertical, 10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .fill(active ? KTColor.accentSoft : (hovering ? KTColor.btnHover : Color.white))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .stroke(active ? KTColor.accent : Color(hex: 0xE6E6EC), lineWidth: active ? 1.5 : 0.5)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
    }
}
