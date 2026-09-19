import AppKit
import KTPlatformContracts
import KTPluginKit
import SwiftUI

struct SiteQuickEditorButton: View {
    let site: SiteSummary

    @State private var catalog = CodeEditorCatalog(locate: { _ in nil })
    @State private var hovering = false

    var body: some View {
        if !site.path.isEmpty, let preferred = catalog.preferred() {
            Button {
                SiteActions.openInEditor(site, editor: preferred, catalog: catalog)
            } label: {
                Image(systemName: preferred.symbol)
                    .font(.system(size: 14, weight: .regular))
                    .foregroundStyle(hovering ? KTColor.ink : KTColor.ink2)
                    .frame(width: 32, height: 30)
                    .background(hovering ? KTColor.rowHover : Color.clear)
                    .clipShape(RoundedRectangle(cornerRadius: KTRadius.buttonSmall, style: .continuous))
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .onHover { hovering = $0 }
            .ktTip("Open in \(preferred.displayName) (right-click to change)")
            .accessibilityLabel("Open in \(preferred.displayName)")
            .contextMenu {
                Text("Open with:")
                ForEach(catalog.installed) { editor in
                    Button {
                        catalog.setPreferred(editor)
                        SiteActions.openInEditor(site, editor: editor, catalog: catalog)
                    } label: {
                        HStack {
                            Text(editor.displayName)
                            if editor == preferred {
                                Spacer()
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            }
            .onAppear {
                refreshCatalog()
            }
        }
    }

    private func refreshCatalog() {
        catalog = CodeEditorCatalog(locate: {
            NSWorkspace.shared.urlForApplication(withBundleIdentifier: $0)
        })
    }
}
