import KTPlatformContracts
import KTPluginKit
import SwiftUI

struct EngineInspectorView: View {
    let engine: ServiceEngine
    let version: String
    let uninstallBlockReason: String?
    let onUninstall: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Data for \(engine.displayName) \(version) is stored separately from other versions.")
                .font(KTType.sub).foregroundStyle(KTColor.muted)
            dangerZone
        }
        .padding(.vertical, 16)
        .padding(.horizontal, 20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(KTColor.contentBg)
        .overlay(alignment: .leading) { Rectangle().fill(KTColor.accent).frame(width: 3) }
    }

    private var dangerZone: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Danger zone").font(.jbMono(11, .bold)).tracking(0.6).foregroundStyle(KTColor.faint)
            KTButton(title: "Uninstall…", systemImage: "trash", kind: .danger, action: onUninstall)
                .disabled(uninstallBlockReason != nil)
                .opacity(uninstallBlockReason != nil ? 0.4 : 1)
                .help(uninstallBlockReason ?? "")
        }
        .padding(.top, 4)
    }
}
