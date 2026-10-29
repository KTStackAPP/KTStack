import KTPlatformContracts
import KTPluginKit
import SwiftUI

extension SiteInspector {
    func securityCard(_ site: SiteSummary) -> some View {
        InspectorCard(title: "Security & Sharing") {
            InspectorRow("HTTPS") {
                EmptyView()
            } trailing: {
                InspectorSwitch(label: "Serve over HTTPS", isOn: site.secure) { vm.setSecure(site.id, !site.secure) }
            }
            certificateRow(site)
            SiteShareRows(share: vm.shares[site.id], onToggleShare: { actions.toggleShare(site, $0) })
        }
    }

    @ViewBuilder
    private func certificateRow(_ site: SiteSummary) -> some View {
        if let cert = site.customCertificate {
            InspectorRow("Certificate") {
                InspectorHint(Self.customHint(cert))
            } trailing: {
                HStack(spacing: 6) {
                    InspectorButton(title: "Re-import") { actions.reimportCertificate(site) }
                    InspectorButton(title: "Remove", style: .quiet) { actions.removeCertificate(site) }
                }
            }
        } else {
            InspectorRow("Certificate") {
                InspectorHint("Trusted local certificate")
            } trailing: {
                InspectorButton(title: "Use Custom Certificate…") { actions.chooseCertificate(site) }
            }
        }
    }

    static func customHint(_ cert: SiteCertificateSummary) -> String {
        "Custom: \(cert.names.joined(separator: ", ")) · expires \(cert.notAfter.formatted(date: .abbreviated, time: .omitted))"
    }
}
