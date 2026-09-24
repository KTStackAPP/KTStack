import KTPluginKit
import KTStackKit
import SwiftUI

struct NetworkAccessRows: View {
    @ObservedObject var preferences: AppPreferences
    let server: LocalServerController

    var body: some View {
        KTSettingsRow(title: "Serve over HTTPS", subtitle: "Issue trusted local certificates per site.") {
            KTToggle(isOn: preferences.serveHTTPSByDefault) { preferences.serveHTTPSByDefault.toggle() }
        }
        KTSettingsRow(
            title: "Allow devices on your network",
            subtitle: "Off: sites answer only on this Mac. On: phones and other computers on your network can open them.",
            showDivider: false
        ) {
            KTToggle(isOn: preferences.allowLANAccess) {
                preferences.allowLANAccess.toggle()
                server.applyNetworkAccessChange()
            }
        }
    }
}
