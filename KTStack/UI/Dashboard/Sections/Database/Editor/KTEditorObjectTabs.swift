import SwiftUI
import KTStackKit

struct KTEditorObjectTabs<Value: Hashable>: View {
    struct Item: Identifiable {
        let value: Value
        let label: String
        let systemImage: String
        var id: Value { value }
    }

    let items: [Item]
    @Binding var selection: Value

    var body: some View {
        HStack(spacing: 2) {
            ForEach(items) { item in
                let active = item.value == selection
                Button { selection = item.value } label: {
                    HStack(spacing: 6) {
                        Image(systemName: item.systemImage)
                            .font(.system(size: 12, weight: .medium))
                            .opacity(0.8)
                        Text(item.label)
                            .font(.jbMono(12, active ? .medium : .regular))
                    }
                    .foregroundStyle(active ? KTEditorTheme.label : KTEditorTheme.label2)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 7)
                    .background(
                        UnevenRoundedRectangle(topLeadingRadius: 7, topTrailingRadius: 7, style: .continuous)
                            .fill(active ? KTEditorTheme.content : Color.clear))
                    .overlay(alignment: .bottom) {
                        Rectangle()
                            .fill(active ? KTEditorTheme.accent : Color.clear)
                            .frame(height: 1.5)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 12)
        .padding(.top, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(KTEditorTheme.window)
        .overlay(alignment: .bottom) {
            Rectangle().fill(KTEditorTheme.separator).frame(height: 1)
        }
    }
}
