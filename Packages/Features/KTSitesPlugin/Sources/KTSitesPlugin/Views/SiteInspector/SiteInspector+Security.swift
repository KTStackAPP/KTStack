import KTPlatformContracts
import KTPluginKit
import KTStackCore
import SwiftUI

extension SiteInspector {
    func securityCard(_ site: SiteSummary) -> some View {
        InspectorCard(title: "Security & Sharing") {
            InspectorRow("HTTPS") {
                if !site.secure, DNSConstants.isHSTSPreloaded(vm.tld) {
                    InspectorHint("Browsers force HTTPS on .\(vm.tld), so this site won't load until HTTPS is on.", color: Color(nsColor: .systemOrange))
                } else {
                    InspectorHint("Trusted local certificate")
                }
            } trailing: {
                InspectorSwitch(label: "Serve over HTTPS", isOn: site.secure) { vm.setSecure(site.id, !site.secure) }
            }
            SiteShareRows(share: vm.shares[site.id], onToggleShare: { actions.toggleShare(site, $0) })
        }
    }
}
