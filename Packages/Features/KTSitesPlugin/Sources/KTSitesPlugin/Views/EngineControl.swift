import KTPlatformContracts
import KTPluginKit
import SwiftUI

// Đổi engine áp dụng ngay: engine mới lên ở port mới rồi front trỏ sang, không restart Web Server.
struct EngineControl: View {
    let current: SiteServerEngine
    let port: Int?
    let apacheInstalled: Bool
    let apacheInstalling: Bool
    let onSelect: (SiteServerEngine) -> Void
    let onInstallApache: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            if apacheInstalled {
                Picker("Web server", selection: Binding(get: { current }, set: onSelect)) {
                    Text("Nginx").tag(SiteServerEngine.nginx)
                    Text("Apache").tag(SiteServerEngine.apache)
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .controlSize(.small)
                .fixedSize()
                .ktTip("Web engine for this site. Switching applies live, no Web Server restart.")
            } else {
                InspectorValue("Nginx")
                if apacheInstalling {
                    ProgressView().controlSize(.small)
                    InspectorHint("Installing Apache…")
                } else {
                    InspectorButton(title: "Install Apache", style: .quiet, action: onInstallApache)
                }
            }
            if let port {
                InspectorHint("backend :\(port)")
            }
        }
    }
}
