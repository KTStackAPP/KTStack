import KTPlatformContracts
import KTPluginKit
import SwiftUI

struct SitesDNSFooter: View {
    let dns: DNSResolverState
    let tld: String
    let onEnable: () -> Void
    let onDisable: () -> Void
    let onReset: () -> Void

    private var isEnabled: Bool { dns.status == .enabled }

    var body: some View {
        HStack(spacing: 8) {
            KTDot(color: isEnabled ? KTColor.runDot : KTColor.stopDot)
            Text(status)
                .font(.jbMono(11.5))
                .foregroundStyle(KTColor.ink2)
                .lineLimit(1)
                .truncationMode(.middle)
            Spacer()
            Group {
                if dns.isBusy {
                    ProgressView().controlSize(.small)
                } else {
                    KTButton(title: "Reset", kind: .secondary, action: onReset)
                    if isEnabled {
                        KTButton(title: "Disable DNS", kind: .danger, action: onDisable)
                    } else {
                        KTButton(title: "Enable DNS", kind: .secondary, action: onEnable)
                    }
                }
            }
            .controlSize(.small)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .overlay(alignment: .top) { Rectangle().fill(KTColor.sep).frame(height: 0.5) }
    }

    private var status: String {
        isEnabled ? "DNS on · *.\(tld) → this Mac" : "DNS off · *.\(tld) will not resolve"
    }
}
