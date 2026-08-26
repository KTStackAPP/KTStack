import KTPluginKit
import KTStackKit
import SwiftUI

struct DashboardWindow: View {
    static let windowID = "dashboard"

    @ObservedObject var nav: DashboardNavigation
    let env: DashboardEnv
    let pluginSections: [PluginSection]

    @State private var showDNSOnboarding = false

    var body: some View {
        DashboardSplitRepresentable(nav: nav, env: env, sections: pluginSections)
            .frame(minWidth: 720, minHeight: 460)
            .ignoresSafeArea(.container, edges: .top)
            .background(KTWindowChrome())
            .sheet(isPresented: $showDNSOnboarding) { HelperApprovalView(dns: env.dns) }
            // Dashboard mở → poll nhanh + sample metrics; đóng → ServiceManager tự hạ cadence.
            .onAppear { env.services.beginLiveUpdates() }
            .onDisappear { env.services.endLiveUpdates() }
            .task {
                // Prompt DNS setup once on first launch; without it the resolver never gets set up
                // because nothing else surfaces the step at boot.
                if !env.preferences.hasSeenDNSSetup, env.dns.status == .disabled { showDNSOnboarding = true }
                env.preferences.hasSeenDNSSetup = true
            }
    }
}
