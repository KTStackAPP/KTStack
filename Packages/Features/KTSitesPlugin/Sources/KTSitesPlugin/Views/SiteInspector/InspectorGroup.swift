import KTPluginKit
import SwiftUI

struct InspectorGroup<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title.uppercased())
                .font(KTType.sectionLabel)
                .tracking(KTType.sectionLabelTracking)
                .foregroundStyle(KTColor.faint)
            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct InspectorField<Content: View>: View {
    let label: String
    let content: Content

    init(_ label: String, @ViewBuilder content: () -> Content) {
        self.label = label
        self.content = content()
    }

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            Text(label)
                .font(.jbMono(12))
                .foregroundStyle(KTColor.ink3)
                .frame(width: 110, alignment: .leading)
            content.frame(maxWidth: .infinity, alignment: .leading)
        }
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

struct InspectorCaption: View {
    let text: String

    init(_ text: String) {
        self.text = text
    }

    var body: some View {
        Text(text).font(KTType.caption).foregroundStyle(KTColor.muted)
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
