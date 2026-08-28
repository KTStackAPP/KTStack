import KTPluginKit
import SwiftUI

struct V2SheetHeader: View {
    let title: String

    var body: some View {
        VStack(spacing: 0) {
            Text(title)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(KTEditorTheme.label)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 18)
                .padding(.vertical, 16)
            Divider().overlay(KTEditorTheme.separator)
        }
    }
}

struct V2SheetFooter: View {
    var confirmTitle: String = "Preview SQL"
    var confirmDisabled: Bool = false
    var onCancel: () -> Void
    var onConfirm: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Spacer()
            Button("Cancel", action: onCancel)
                .keyboardShortcut(.cancelAction)
            Button(confirmTitle, action: onConfirm)
                .keyboardShortcut(.defaultAction)
                .disabled(confirmDisabled)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
    }
}

/// Multi-select column chips used by the index and foreign-key editors.
struct V2ColumnPicker: View {
    let available: [String]
    @Binding var selected: [String]

    var body: some View {
        FlowRow(spacing: 6) {
            ForEach(available, id: \.self) { column in
                chip(column)
            }
        }
    }

    private func chip(_ column: String) -> some View {
        let isOn = selected.contains(column)
        return Button {
            if isOn { selected.removeAll { $0 == column } } else { selected.append(column) }
        } label: {
            Text(column)
                .font(.jbMono(12))
                .foregroundStyle(isOn ? KTEditorTheme.onAccent : KTEditorTheme.label)
                .padding(.horizontal, 9)
                .padding(.vertical, 4)
                .background(
                    isOn ? KTEditorTheme.accent : KTEditorTheme.pillBg,
                    in: RoundedRectangle(cornerRadius: 6)
                )
        }
        .buttonStyle(.plain)
    }
}

/// Minimal wrapping row so column chips flow onto multiple lines.
struct FlowRow: Layout {
    var spacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout Void) -> CGSize {
        let maxWidth = proposal.width ?? 400
        var cursorX: CGFloat = 0
        var cursorY: CGFloat = 0
        var rowHeight: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if cursorX + size.width > maxWidth, cursorX > 0 {
                cursorX = 0
                cursorY += rowHeight + spacing
                rowHeight = 0
            }
            cursorX += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
        return CGSize(width: maxWidth, height: cursorY + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout Void) {
        var cursorX = bounds.minX
        var cursorY = bounds.minY
        var rowHeight: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if cursorX + size.width > bounds.maxX, cursorX > bounds.minX {
                cursorX = bounds.minX
                cursorY += rowHeight + spacing
                rowHeight = 0
            }
            subview.place(at: CGPoint(x: cursorX, y: cursorY), proposal: .unspecified)
            cursorX += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}
