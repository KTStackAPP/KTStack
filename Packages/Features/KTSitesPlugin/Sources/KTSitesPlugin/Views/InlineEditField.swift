import KTPluginKit
import SwiftUI

// Shows the value as Text and swaps in a TextField only while editing. A TextField is backed by an
// NSTextField, which is costly to create while LazyVStack rows scroll in, and most rows are never
// edited. Return commits, Escape or clicking away cancels.
struct InlineEditField: View {
    let placeholder: String
    @Binding var text: String
    var color: Color = KTColor.ink
    var alignment: Alignment = .leading
    let onSubmit: () -> Void
    let onCancel: () -> Void

    @State private var editing = false
    @FocusState private var focused: Bool

    private static let font = Font.jbMono(12.5)

    var body: some View {
        if editing {
            TextField(placeholder, text: $text)
                .textFieldStyle(.plain)
                .font(Self.font)
                .foregroundStyle(color)
                .lineLimit(1)
                .focused($focused)
                .onSubmit {
                    editing = false
                    onSubmit()
                }
                .onExitCommand(perform: cancel)
                .onChange(of: focused) { if !$0 { cancel() } }
                // A freshly inserted field can't take focus in the same update on macOS.
                .onAppear { DispatchQueue.main.async { focused = true } }
        } else {
            Text(text.isEmpty ? placeholder : text)
                .font(Self.font)
                .foregroundStyle(text.isEmpty ? KTColor.faint : color)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: alignment)
                .contentShape(Rectangle())
                .onTapGesture { editing = true }
                .accessibilityAddTraits(.isButton)
                .accessibilityAction { editing = true }
        }
    }

    private func cancel() {
        guard editing else { return }
        editing = false
        onCancel()
    }
}
