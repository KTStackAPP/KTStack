import KTPluginKit
import SwiftUI

struct SitesHeader: View {
    let siteCount: Int
    let isRunning: Bool
    let isBusy: Bool
    let onToggleServer: () -> Void
    let onScan: () -> Void
    let onNewSite: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Text("Sites")
                .font(KTType.screenTitle)
                .tracking(KTType.screenTitleTracking)
                .foregroundStyle(KTColor.ink)
            KTPill(text: "\(siteCount)")
            Spacer()
            serverControl
            KTButton(title: "Scan", systemImage: "arrow.triangle.2.circlepath", kind: .secondary, action: onScan)
            newSiteButton
        }
    }

    private var serverControl: some View {
        HStack(spacing: 8) {
            KTDot(color: isRunning ? KTColor.runDot : KTColor.stopDot)
            Text(isRunning ? "Server running" : "Server stopped")
                .font(.jbMono(12.5))
                .foregroundStyle(KTColor.ink)
            KTButton(title: isRunning ? "Stop" : "Start", kind: .secondary, action: onToggleServer)
                .controlSize(.small)
                .disabled(isBusy)
        }
        .padding(.leading, 10)
        .padding(.trailing, 3)
        .padding(.vertical, 3)
        .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).stroke(KTColor.sep, lineWidth: 1))
    }

    private var newSiteButton: some View {
        Button(action: onNewSite) {
            HStack(spacing: 7) {
                Image(systemName: "plus").font(.system(size: 13, weight: .bold))
                Text("New Site").font(.jbMono(13, .regular))
            }
            .foregroundStyle(.white)
            .padding(.vertical, 9)
            .padding(.horizontal, 15)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .keyboardShortcut("n", modifiers: .command)
        .background(KTColor.accentGradient)
        .clipShape(RoundedRectangle(cornerRadius: KTRadius.button, style: .continuous))
    }
}
