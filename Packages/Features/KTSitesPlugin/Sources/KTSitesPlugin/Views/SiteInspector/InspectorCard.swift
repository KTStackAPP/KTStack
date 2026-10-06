import KTPluginKit
import SwiftUI

struct InspectorCard<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title.uppercased())
                .font(KTType.sectionLabel)
                .tracking(KTType.sectionLabelTracking)
                .foregroundStyle(KTColor.muted)
                .padding(.leading, 2)
            VStack(spacing: 0) { content }
                .background(KTColor.cardBg)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).stroke(KTColor.sep, lineWidth: 1))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// Hàng trong card: nhãn cố định, giá trị co giãn, control ở mép phải; vạch ngăn ở mép trên.
struct InspectorRow<Value: View, Trailing: View>: View {
    let label: String
    let value: Value
    let trailing: Trailing

    init(_ label: String, @ViewBuilder value: () -> Value, @ViewBuilder trailing: () -> Trailing) {
        self.label = label
        self.value = value()
        self.trailing = trailing()
    }

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Text(label)
                .font(.jbMono(12.5))
                .foregroundStyle(KTColor.ink2)
                .frame(width: 130, alignment: .leading)
            value.frame(maxWidth: .infinity, alignment: .leading)
            trailing.fixedSize()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .frame(minHeight: 46)
        .overlay(alignment: .top) { Rectangle().fill(KTColor.hairline).frame(height: 1) }
    }
}

extension InspectorRow where Trailing == EmptyView {
    init(_ label: String, @ViewBuilder value: () -> Value) {
        self.init(label, value: value) { EmptyView() }
    }
}

struct InspectorHint: View {
    let text: String
    let color: Color

    init(_ text: String, color: Color = KTColor.muted) {
        self.text = text
        self.color = color
    }

    var body: some View {
        Text(text)
            .font(.jbMono(11.5))
            .foregroundStyle(color)
            .fixedSize(horizontal: false, vertical: true)
    }
}

struct InspectorSwitch: View {
    let label: String
    let isOn: Bool
    let action: () -> Void

    var body: some View {
        Toggle(label, isOn: Binding(get: { isOn }, set: { _ in action() }))
            .toggleStyle(.switch)
            .labelsHidden()
            .controlSize(.small)
    }
}

struct InspectorButton: View {
    enum Style { case bordered, quiet }

    let title: String
    var style: Style = .bordered
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.jbMono(12))
                .foregroundStyle(style == .quiet ? KTColor.accent : KTColor.ink)
                .padding(.vertical, 3)
                .padding(.horizontal, 9)
                .background(
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(style == .quiet ? Color.clear : KTColor.fieldBg)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .stroke(style == .quiet ? Color.clear : KTColor.btnBorder, lineWidth: 1)
                )
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

struct InspectorValue: View {
    let text: String
    let muted: Bool
    let truncation: Text.TruncationMode

    init(_ text: String, muted: Bool = false, truncation: Text.TruncationMode = .tail) {
        self.text = text
        self.muted = muted
        self.truncation = truncation
    }

    var body: some View {
        Text(text)
            .font(.jbMono(12.5))
            .foregroundStyle(muted ? KTColor.muted : KTColor.ink)
            .lineLimit(1)
            .truncationMode(truncation)
            .textSelection(.enabled)
    }
}

struct InspectorError: View {
    let text: String

    init(_ text: String) {
        self.text = text
    }

    var body: some View {
        Text(text).font(.jbMono(11.5)).foregroundStyle(KTColor.danger).fixedSize(horizontal: false, vertical: true)
    }
}
