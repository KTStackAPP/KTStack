import SwiftUI

public struct KTSearchField: View {
    @Binding public var text: String
    public var placeholder: String = "Search…"

    public init(text: Binding<String>, placeholder: String = "Search…") {
        _text = text
        self.placeholder = placeholder
    }

    public var body: some View {
        HStack(spacing: 9) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(KTColor.ink2)
            TextField(placeholder, text: $text)
                .textFieldStyle(.plain)
                .font(.jbMono(14))
                .foregroundStyle(KTColor.ink)
            if !text.isEmpty {
                Button { text = "" } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(KTColor.ink2)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Clear search")
            }
        }
        .padding(.vertical, 9)
        .padding(.horizontal, 14)
        .ktLiquidGlassInteractive(cornerRadius: KTRadius.field)
    }
}
