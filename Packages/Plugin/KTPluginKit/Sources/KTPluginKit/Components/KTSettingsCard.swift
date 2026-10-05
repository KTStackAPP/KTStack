import SwiftUI

public struct KTSettingsGroup<Content: View>: View {
    public let title: String
    @ViewBuilder public var content: () -> Content

    public init(title: String, @ViewBuilder content: @escaping () -> Content) {
        self.title = title
        self.content = content
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title.uppercased())
                .font(.jbMono(12, .bold)).tracking(0.5)
                .foregroundStyle(KTColor.ink2)
                .padding(.bottom, 9)
            VStack(spacing: 0) { content() }
                .ktLiquidGlassCard(cornerRadius: 13)
        }
        .padding(.bottom, 22)
    }
}

public struct KTSettingsRow<Trailing: View>: View {
    public let title: String
    public var subtitle: String?
    public var showDivider = true
    @ViewBuilder public var trailing: () -> Trailing

    public init(
        title: String,
        subtitle: String? = nil,
        showDivider: Bool = true,
        @ViewBuilder trailing: @escaping () -> Trailing
    ) {
        self.title = title
        self.subtitle = subtitle
        self.showDivider = showDivider
        self.trailing = trailing
    }

    public var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.jbMono(14, .regular)).foregroundStyle(KTColor.ink)
                if let subtitle {
                    Text(subtitle).font(.jbMono(12.5)).foregroundStyle(KTColor.ink2)
                }
            }
            Spacer(minLength: 12)
            trailing()
        }
        .padding(.horizontal, 18).padding(.vertical, 14)
        .overlay(alignment: .bottom) {
            if showDivider { Rectangle().fill(KTColor.sepFaint).frame(height: 0.5) }
        }
    }
}

public struct KTSettingsMenuValue: View {
    public let text: String
    public var mono = false

    public init(text: String, mono: Bool = false) {
        self.text = text
        self.mono = mono
    }

    public var body: some View {
        HStack(spacing: 7) {
            Text(text)
                .font(.jbMono(13, mono ? .regular : .medium))
                .foregroundStyle(mono ? KTColor.ink2 : KTColor.ink)
            Image(systemName: "chevron.down").font(.system(size: 10, weight: .regular)).foregroundStyle(KTColor.ink2)
        }
        .padding(.horizontal, 12).padding(.vertical, 7)
        .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(KTColor.fieldBg))
        .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).stroke(KTColor.fieldBorder, lineWidth: 0.5))
    }
}

public struct KTSettingsValuePill: View {
    public let text: String
    public var mono = true

    public init(text: String, mono: Bool = true) {
        self.text = text
        self.mono = mono
    }

    public var body: some View {
        Text(text)
            .font(.jbMono(13, .regular))
            .foregroundStyle(KTColor.ink2)
            .padding(.horizontal, 12).padding(.vertical, 7)
            .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(KTColor.fieldBg))
            .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).stroke(KTColor.fieldBorder, lineWidth: 0.5))
    }
}

public struct KTSettingsTextButton: View {
    public let title: String
    public var danger = false
    public let action: () -> Void

    @State private var hovering = false

    public init(title: String, danger: Bool = false, action: @escaping () -> Void) {
        self.title = title
        self.danger = danger
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            Text(title).font(.jbMono(13, .medium))
                .foregroundStyle(danger ? KTColor.danger : KTColor.ink)
                .padding(.horizontal, 14).padding(.vertical, 7)
                .background(
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .fill(hovering ? (danger ? KTColor.dangerBg : KTColor.btnHover) : Color.white)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .stroke(danger ? KTColor.dangerBorder : KTColor.btnBorder, lineWidth: 0.5)
                )
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
    }
}
