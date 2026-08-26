import KTPluginKit
import SwiftUI

struct EditablePairList: View {
    @Binding var pairs: [EditablePair]
    var keyPlaceholder: String
    var valuePlaceholder: String
    var lockKeys: Bool = false
    var keySuggestions: [String] = []
    var variableNames: [String] = []

    var body: some View {
        VStack(spacing: 6) {
            ForEach($pairs) { $pair in
                HStack(spacing: 8) {
                    fieldBox(disabled: lockKeys) {
                        field(text: $pair.key, placeholder: keyPlaceholder, disabled: lockKeys)
                        if !lockKeys, !keySuggestions.isEmpty {
                            pickerMenu(icon: "chevron.down", items: keySuggestions) { pair.key = $0 }
                        }
                    }
                    .frame(width: 170)
                    fieldBox(disabled: false) {
                        if variableNames.isEmpty {
                            field(text: $pair.value, placeholder: valuePlaceholder, disabled: false)
                        } else {
                            VariableTextField(
                                text: $pair.value,
                                placeholder: valuePlaceholder,
                                variableNames: variableNames
                            )
                            .frame(maxWidth: .infinity)
                        }
                    }
                    if !lockKeys {
                        Button { pairs.removeAll { $0.id == pair.id } } label: {
                            Image(systemName: "minus.circle").font(.system(size: 13)).foregroundStyle(KTColor.muted)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            if !lockKeys {
                Button { pairs.append(EditablePair(key: "", value: "")) } label: {
                    Label("Add", systemImage: "plus").font(.jbMono(11.5)).foregroundStyle(KTColor.accent)
                }
                .buttonStyle(.plain)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private func fieldBox(disabled _: Bool, @ViewBuilder _ content: () -> some View) -> some View {
        HStack(spacing: 4) { content() }
            .padding(.horizontal, 9).padding(.vertical, 6)
            .background(RoundedRectangle(cornerRadius: 7, style: .continuous).fill(Color(hex: 0xFBFBFC)))
            .overlay(RoundedRectangle(cornerRadius: 7, style: .continuous).stroke(KTColor.fieldBorder, lineWidth: 0.5))
    }

    private func field(text: Binding<String>, placeholder: String, disabled: Bool) -> some View {
        TextField(placeholder, text: text)
            .textFieldStyle(.plain)
            .font(.jbMono(12))
            .foregroundStyle(disabled ? KTColor.ink3 : KTColor.ink)
            .disabled(disabled)
    }

    private func pickerMenu(icon: String, items: [String], onPick: @escaping (String) -> Void) -> some View {
        Menu {
            ForEach(items, id: \.self) { item in
                Button(item) { onPick(item) }
            }
        } label: {
            Image(systemName: icon).font(.system(size: 10, weight: .medium)).foregroundStyle(KTColor.muted)
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
    }
}
