import KTPlatformContracts
import KTPluginKit
import SwiftUI

// Nút tách: phần trái mở editor ưa thích, mũi tên chọn editor khác và nhớ lựa chọn.
struct SiteEditorButton: View {
    let site: SiteSummary
    let catalog: CodeEditorCatalog
    let preferred: CodeEditor
    let showsName: Bool

    var body: some View {
        HStack(spacing: 0) {
            Button {
                SiteActions.openInEditor(site, editor: preferred, catalog: catalog)
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: preferred.symbol).font(.system(size: 13))
                    if showsName {
                        Text(preferred.displayName).font(.jbMono(12.5)).lineLimit(1)
                    }
                }
                .foregroundStyle(KTColor.ink)
                .padding(.horizontal, 10)
                .frame(height: 30)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .ktTip("Open in \(preferred.displayName)")
            .accessibilityLabel("Open in \(preferred.displayName)")

            Rectangle().fill(KTColor.btnBorder).frame(width: 1, height: 30)

            Menu {
                ForEach(catalog.installed) { editor in
                    Button {
                        catalog.setPreferred(editor)
                        SiteActions.openInEditor(site, editor: editor, catalog: catalog)
                    } label: {
                        if editor == preferred {
                            Label(editor.displayName, systemImage: "checkmark")
                        } else {
                            Text(editor.displayName)
                        }
                    }
                }
            } label: {
                Image(systemName: "chevron.down").font(.system(size: 10, weight: .semibold))
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .frame(width: 26, height: 30)
            .accessibilityLabel("Open with another editor")
        }
        .background(RoundedRectangle(cornerRadius: 7, style: .continuous).fill(KTColor.fieldBg))
        .overlay(RoundedRectangle(cornerRadius: 7, style: .continuous).stroke(KTColor.btnBorder, lineWidth: 1))
        .fixedSize()
    }
}
