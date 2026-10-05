import KTPlatformContracts
import KTPluginKit
import SwiftUI

extension SiteInspector {
    func securityGroup(_ site: SiteSummary) -> some View {
        InspectorGroup(title: "Security") {
            InspectorField("HTTPS") {
                VStack(alignment: .leading, spacing: 3) {
                    KTToggle("Serve \(site.name) over HTTPS", isOn: site.secure) { vm.setSecure(site.id, !site.secure) }
                        .accessibilityLabel("Serve over HTTPS")
                    InspectorCaption("Trusted local certificate")
                }
            }
            InspectorField("Public URL") {
                VStack(alignment: .leading, spacing: 3) {
                    SiteShareControls(share: vm.shares[site.id], onToggleShare: { actions.toggleShare(site, $0) })
                    InspectorCaption("Share through Cloudflare Tunnel")
                }
            }
        }
    }
}
