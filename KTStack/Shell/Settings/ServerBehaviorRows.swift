import KTPluginKit
import KTStackKit
import SwiftUI

struct ServerBehaviorRows: View {
    @ObservedObject var preferences: AppPreferences

    var body: some View {
        KTSettingsRow(title: "Auto-start server", subtitle: "Bring the server up automatically on launch.") {
            KTToggle("Auto-start server", isOn: preferences.autoStartServer) { preferences.autoStartServer.toggle() }
        }
        KTSettingsRow(
            title: "Queue actions while busy",
            subtitle: "Run a start, stop or restart clicked during another server operation once it finishes. Off: the click is ignored."
        ) {
            KTToggle("Queue actions while busy", isOn: preferences.queueServerActions) { preferences.queueServerActions.toggle() }
        }
    }
}
