import SwiftUI

public struct KTSegmentedTabs<Value: Hashable>: View {
    public struct Item: Identifiable {
        public let value: Value
        public let label: String
        public var id: Value {
            value
        }

        public init(value: Value, label: String) {
            self.value = value
            self.label = label
        }
    }

    public let items: [Item]
    @Binding public var selection: Value
    public var large = false

    public init(items: [Item], selection: Binding<Value>, large: Bool = false) {
        self.items = items
        self._selection = selection
        self.large = large
    }

    private var fontSize: CGFloat {
        large ? 14 : 13
    }

    private var vPad: CGFloat {
        large ? 8 : 5
    }

    private var hPad: CGFloat {
        large ? 18 : 13
    }

    public var body: some View {
        HStack(spacing: 2) {
            ForEach(items) { item in
                let active = item.value == selection
                Button { selection = item.value } label: {
                    Text(item.label)
                        .font(.jbMono(fontSize, active ? .regular : .medium))
                        .foregroundStyle(active ? KTColor.ink : KTColor.ink3)
                        .padding(.vertical, vPad)
                        .padding(.horizontal, hPad)
                        .background(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(active ? Color.white : Color.clear)
                                .shadow(color: active ? .black.opacity(0.10) : .clear, radius: 1.5, y: 1)
                        )
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(3)
        .background(RoundedRectangle(cornerRadius: KTRadius.segment, style: .continuous).fill(KTColor.segmentBg))
    }
}
