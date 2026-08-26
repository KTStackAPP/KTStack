import KTPluginKit
import SwiftUI

extension NewSiteForm {
    var createFooter: some View {
        HStack(spacing: 10) {
            if model.finished {
                Spacer()
                KTButton(title: "Done", kind: .primary) { onClose() }
            } else if model.installing {
                Spacer()
                KTButton(title: "Cancel", kind: .secondary) { model.cancel() }
            } else if model.error != nil {
                Spacer()
                KTButton(title: "Back", kind: .secondary) { model.reset() }
                KTButton(title: "Try Again", kind: .primary) { create() }
            } else {
                resolvesLabel(domain)
                Spacer()
                KTButton(title: "Cancel", kind: .secondary) { onClose() }
                KTButton(title: "Create Site", systemImage: "plus", kind: .primary) { create() }
                    .disabled(slug.isEmpty || availableVersions.isEmpty)
            }
        }
        .padding(16)
        .padding(.horizontal, 8)
        .overlay(alignment: .top) { SiteFormControls.hairline }
    }

    var importFooter: some View {
        HStack(spacing: 10) {
            if model.finished {
                Spacer()
                KTButton(title: "Done", kind: .primary) { onClose() }
            } else if model.installing {
                Spacer()
                KTButton(title: "Cancel", kind: .secondary) { model.cancel() }
            } else if model.error != nil {
                Spacer()
                KTButton(title: "Back", kind: .secondary) { model.reset() }
                KTButton(title: "Try Again", kind: .primary) { importSite() }
            } else {
                resolvesLabel(importDomain)
                Spacer()
                KTButton(title: "Cancel", kind: .secondary) { onClose() }
                KTButton(title: "Import Site", systemImage: "square.and.arrow.down", kind: .primary) { importSite() }
                    .disabled(importFolder == nil || importSlug.isEmpty || availableVersions.isEmpty)
            }
        }
        .padding(16)
        .padding(.horizontal, 8)
        .overlay(alignment: .top) { SiteFormControls.hairline }
    }

    func resolvesLabel(_ value: String) -> some View {
        Text("Resolves at ")
            .font(.jbMono(12.5)).foregroundColor(KTColor.muted)
            + Text(value.isEmpty ? "" : value)
            .font(.jbMono(12.5, .regular)).foregroundColor(KTColor.accent)
    }
}
