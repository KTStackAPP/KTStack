import KTPluginKit
import KTStackKit
import SwiftUI

struct KTSidebarFooterCard: View {
    let status: ServiceStatus
    let version: String

    @EnvironmentObject private var updater: UpdaterController

    var body: some View {
        HStack(spacing: 10) {
            KTDot(color: dotColor)
            VStack(alignment: .leading, spacing: 1) {
                Text("Server \(status.label)")
                    .font(.jbMono(13, .regular))
                    .foregroundStyle(KTColor.ink)
                if let newVersion = updater.availableVersion {
                    Button { updater.checkForUpdates() } label: {
                        Text("Update to v\(newVersion) →")
                            .font(.jbMono(11.5, .medium))
                            .foregroundStyle(KTColor.accent)
                    }
                    .buttonStyle(.plain)
                    .help("A new version is available. Click to update.")
                } else {
                    Text("v\(version)")
                        .font(.jbMono(11.5))
                        .foregroundStyle(KTColor.ink2)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(11)
        .ktLiquidGlassCard(cornerRadius: 11)
    }

    private var dotColor: Color {
        switch status {
        case .running: KTColor.runDot
        case .starting: KTColor.accent
        case .error: KTColor.danger
        case .warning: Color(hex: 0xFF9F0A)
        default: KTColor.stopDot
        }
    }
}
