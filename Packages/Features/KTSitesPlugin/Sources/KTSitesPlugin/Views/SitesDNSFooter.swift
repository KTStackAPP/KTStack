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
            Image(systemName: isEnabled ? "checkmark.shield" : "exclamationmark.shield")
                .font(.system(size: 13))
                .foregroundStyle(isEnabled ? KTColor.online : Color(nsColor: .systemOrange))
            Text(status)
                .font(.jbMono(11.5))
                .foregroundStyle(KTColor.ink2)
                .lineLimit(1)
                .layoutPriority(1)
            Spacer(minLength: 4)
            if dns.isBusy {
                ProgressView().controlSize(.small)
            } else {
                quietButton("Reset", color: KTColor.ink, action: onReset)
                if isEnabled {
                    quietButton("Disable", color: KTColor.danger, action: onDisable)
                } else {
                    quietButton("Enable", color: KTColor.accent, action: onEnable)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .overlay(alignment: .top) { Rectangle().fill(KTColor.sep).frame(height: 1) }
    }

    private func quietButton(_ title: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.jbMono(11.5))
                .foregroundStyle(color)
                .padding(.vertical, 3)
                .padding(.horizontal, 8)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(title) DNS")
    }

    private var status: String {
        isEnabled ? "DNS on · *.\(tld) → this Mac" : "DNS off · *.\(tld) will not resolve"
    }
}
