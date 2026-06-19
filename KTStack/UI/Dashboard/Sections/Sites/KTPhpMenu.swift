import SwiftUI
import KTStackKit

struct KTPhpMenu: View {
    let current: String
    let versions: [String]
    let onSelect: (String) -> Void

    var body: some View {
        Menu {
            ForEach(versions, id: \.self) { version in
                Button { onSelect(version) } label: {
                    if version == current {
                        Label("PHP \(version)", systemImage: "checkmark")
                    } else {
                        Text("PHP \(version)")
                    }
                }
            }
        } label: {
            HStack(spacing: 6) {
                Text("PHP \(current)")
                    .font(.system(size: 12.5, weight: .medium))
                    .foregroundStyle(KTColor.ink2)
                Image(systemName: "chevron.down")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(KTColor.muted)
            }
            .padding(.vertical, 6)
            .padding(.horizontal, 11)
            .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(KTColor.fieldBg))
            .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).strokeBorder(KTColor.fieldBorder, lineWidth: 0.5))
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
    }
}
