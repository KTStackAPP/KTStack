import SwiftUI
import KTStackKit

struct KTSidebarFooterCard: View {
    let status: ServiceStatus
    let version: String

    var body: some View {
        HStack(spacing: 10) {
            KTDot(color: dotColor)
            VStack(alignment: .leading, spacing: 1) {
                Text("Server \(status.label)")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(KTColor.ink)
                Text("v\(version)")
                    .font(.system(size: 11.5))
                    .foregroundStyle(KTColor.muted)
            }
            Spacer(minLength: 0)
        }
        .padding(11)
        .background(RoundedRectangle(cornerRadius: 11, style: .continuous).fill(Color.white.opacity(0.7)))
        .overlay(RoundedRectangle(cornerRadius: 11, style: .continuous).strokeBorder(Color(hex: 0xE8E8EE), lineWidth: 0.5))
    }

    private var dotColor: Color {
        switch status {
        case .running: return KTColor.runDot
        case .starting: return KTColor.accent
        case .error: return KTColor.danger
        case .warning: return Color(hex: 0xFF9F0A)
        default: return KTColor.stopDot
        }
    }
}
