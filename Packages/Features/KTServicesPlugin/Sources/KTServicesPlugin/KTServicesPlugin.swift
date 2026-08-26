import KTPlatformContracts
import KTPluginKit
import SwiftUI

// Sidebar plugin sở hữu màn Services. Stream subscribe lazy khi VM khởi tạo (makeContentView đầu
// tiên); không lifecycle/activation. beginLiveUpdates vẫn do DashboardWindow gọi theo window.
public final class KTServicesPlugin: KTStackPlugin {
    public let descriptor = PluginDescriptor(id: "services", title: "Services", systemImage: "server.rack")

    private let services: any ServiceManaging
    private let engines: any ServiceEngineVersionManaging
    private let dns: any DNSResolverManaging
    private let caTrust: any CATrustProviding
    private let nginxInclude: any NginxIncludeEditing
    private let route: @MainActor (ServicesRoute) -> Void

    @MainActor private lazy var vm = ServicesViewModel(
        services: services, engines: engines, dns: dns, caTrust: caTrust
    )
    @MainActor private let feedback = KTFeedbackCenter()

    public init(
        services: any ServiceManaging,
        engines: any ServiceEngineVersionManaging,
        dns: any DNSResolverManaging,
        caTrust: any CATrustProviding,
        nginxInclude: any NginxIncludeEditing,
        route: @escaping @MainActor (ServicesRoute) -> Void
    ) {
        self.services = services
        self.engines = engines
        self.dns = dns
        self.caTrust = caTrust
        self.nginxInclude = nginxInclude
        self.route = route
    }

    @MainActor public func makeContentView() -> AnyView {
        AnyView(
            ServicesScreen(vm: vm, nginxInclude: nginxInclude, route: route)
                .environmentObject(feedback)
        )
    }
}
