import KTPluginKit
import KTStackKit
import SwiftUI

struct CANameConstraintSection: View {
    @ObservedObject var caTrust: CATrustService
    let server: LocalServerController
    @AppStorage(RestrictedRootCA.policyKey) private var restrictCA = true

    var body: some View {
        Section {
            Toggle("Restrict CA to dev domains", isOn: $restrictCA)
            LabeledContent("Current CA") {
                Text(scopeText).foregroundStyle(needsRegeneration ? Color.KDStatus.warning : .secondary)
            }
            if restrictCA, needsRegeneration {
                HStack {
                    Spacer()
                    Button("Regenerate CA") {
                        let server = server
                        caTrust.regenerateRestrictedCA { server.renewCertificatesAfterCAChange() }
                    }
                    .disabled(caTrust.isBusy)
                }
            }
        } header: {
            Text("Name constraints")
        } footer: {
            Text(footerText).font(.caption2).foregroundStyle(.secondary)
        }
    }

    private var needsRegeneration: Bool {
        switch caTrust.coverage {
        case .none: false
        case .unrestricted: true
        case .restricted: !caTrust.currentTLDCovered
        }
    }

    private var scopeText: String {
        switch caTrust.coverage {
        case .none: "Not created yet"
        case .unrestricted: "Can sign any domain"
        case let .restricted(tlds) where !caTrust.currentTLDCovered:
            "Does not cover .\(RestrictedRootCA.currentTLD()) (\(tlds.map { "." + $0 }.joined(separator: ", ")))"
        case let .restricted(tlds): "Only \(tlds.map { "." + $0 }.joined(separator: ", ")) and loopback IPs"
        }
    }

    private var footerText: String {
        "On: a new local CA can only sign certificates for your dev domains, so a leaked CA key cannot be used against real websites. "
            + "Regenerating replaces the CA (the old one is kept in the CA folder, not deleted), asks you to approve trusting the new CA, "
            + "and re-issues the certificates of your HTTPS sites. Off: new CAs are created by mkcert without restrictions."
    }
}
