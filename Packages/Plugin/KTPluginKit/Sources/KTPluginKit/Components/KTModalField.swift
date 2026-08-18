import SwiftUI

public struct KTModalField: View {
    public let placeholder: String
    @Binding public var text: String
    public var mono = false
    public var isSecure = false

    @FocusState private var focused: Bool

    public init(placeholder: String, text: Binding<String>, mono: Bool = false, isSecure: Bool = false) {
        self.placeholder = placeholder
        self._text = text
        self.mono = mono
        self.isSecure = isSecure
    }

    public var body: some View {
        Group {
            if isSecure {
                SecureField(placeholder, text: $text)
            } else {
                TextField(placeholder, text: $text)
            }
        }
        .textFieldStyle(.plain)
        .font(.jbMono(14))
        .foregroundStyle(KTColor.ink)
        .focused($focused)
        .padding(.horizontal, 13).padding(.vertical, 10)
        .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Color.white))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(focused ? KTColor.accent : Color(hex: 0xE2E2E8), lineWidth: 1.5)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(KTColor.accentSoft, lineWidth: focused ? 3 : 0)
                .blur(radius: 1)
        )
        .animation(.easeOut(duration: 0.12), value: focused)
    }
}

public struct KTModalLabeledRow<Content: View>: View {
    public let label: String
    public var labelWidth: CGFloat = 130
    @ViewBuilder public var content: () -> Content

    public init(label: String, labelWidth: CGFloat = 130, @ViewBuilder content: @escaping () -> Content) {
        self.label = label
        self.labelWidth = labelWidth
        self.content = content
    }

    public var body: some View {
        HStack(spacing: 14) {
            Text(label)
                .font(.jbMono(13.5, .regular))
                .foregroundStyle(KTColor.ink)
                .frame(width: labelWidth, alignment: .leading)
            content()
        }
    }
}
