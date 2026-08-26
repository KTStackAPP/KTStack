import KTPluginKit
import KTStackCore
import SwiftUI

extension NewSiteForm {
    var proxyForm: some View {
        VStack(alignment: .leading, spacing: 18) {
            SiteFormControls.row("Site Name", topAligned: true) {
                VStack(alignment: .leading, spacing: 7) {
                    SiteFormControls.fieldBox {
                        SiteFormControls.smallTile(KTIconTint.cube) { KTSiteGlyph(kind: .proxy, size: 15, color: KTIconTint.cube.fg) }
                        TextField("api", text: $name).textFieldStyle(.plain).font(.jbMono(14.5)).foregroundStyle(KTColor.ink)
                    }
                    SiteFormControls.helper("Serves at \(domain).")
                }
            }
            SiteFormControls.row("Target URL", topAligned: true) {
                VStack(alignment: .leading, spacing: 7) {
                    SiteFormControls.fieldBox {
                        TextField("http://127.0.0.1:8000", text: $proxyTarget).textFieldStyle(.plain).font(.jbMono(14.5)).foregroundStyle(KTColor.ink)
                    }
                    if let error = proxyTargetError {
                        Text(error).font(.jbMono(12.5)).foregroundStyle(KTColor.danger)
                    } else {
                        SiteFormControls.helper("KTStack proxies this site to the upstream. It does not run it.")
                    }
                }
            }

            SiteFormControls.hairline

            SiteFormControls.advancedToggle("Serve over HTTPS", "Issue a trusted local certificate.", $serveHTTPS)
        }
    }
}
