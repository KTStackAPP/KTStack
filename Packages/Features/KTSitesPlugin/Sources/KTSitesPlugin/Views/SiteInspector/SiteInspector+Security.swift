import KTPlatformContracts
import KTPluginKit
import SwiftUI

extension SiteInspector {
    func securityCard(_ site: SiteSummary) -> some View {
        InspectorCard(title: "Security & Sharing") {
            InspectorRow("HTTPS") {
                InspectorHint("Trusted local certificate")
            } trailing: {
                InspectorSwitch(label: "Serve over HTTPS", isOn: site.secure) { vm.setSecure(site.id, !site.secure) }
            }
            SiteShareRows(share: vm.shares[site.id], onToggleShare: { actions.toggleShare(site, $0) })
        }
    }
}
