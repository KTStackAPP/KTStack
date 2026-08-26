import KTPluginKit
import SwiftUI

extension NewSiteForm {
    var adminPasswordSection: some View {
        SiteFormControls.row("Admin Password", topAligned: true) {
            VStack(alignment: .leading, spacing: 7) {
                SiteFormControls.fieldBox {
                    Image(systemName: "lock").font(.system(size: 14, weight: .regular)).foregroundStyle(KTColor.muted)
                    Text(adminPassword).font(.jbMono(14)).foregroundStyle(KTColor.ink)
                    Spacer(minLength: 0)
                    SiteFormControls.iconButton("arrow.clockwise") { adminPassword = NewSiteForm.randomPassword() }
                    SiteFormControls.iconButton("doc.on.doc") {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(adminPassword, forType: .string)
                    }
                }
                SiteFormControls.helper("This password will be used for the \(kindLabel(kind)) admin account.")
            }
        }
    }
}
