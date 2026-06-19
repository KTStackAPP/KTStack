import SwiftUI
import KTStackKit

struct KTDashboardShell<Content: View>: View {
    @Binding var selection: SidebarItem
    let siteCount: Int
    let serverStatus: ServiceStatus
    let version: String
    @ViewBuilder var content: () -> Content

    var body: some View {
        HStack(spacing: 0) {
            KTSidebar(selection: $selection,
                      siteCount: siteCount,
                      serverStatus: serverStatus,
                      version: version)
            VStack(spacing: 0) {
                Color.clear.frame(height: KTMetric.trafficLightInset - 18)
                content()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(KTColor.contentBg)
        }
        .frame(minWidth: 720, minHeight: 460)
        .ignoresSafeArea(.container, edges: .top)
        .background(KTWindowChrome())
    }
}
