import Foundation
import KTPlatformContracts
import KTPluginKit
import SwiftUI

public final class KTSitesPlugin: KTStackPlugin, SectionActivationObserving {
    public let descriptor = PluginDescriptor(id: "sites", title: "Sites", systemImage: "globe")

    private let catalog: any SiteCatalogManaging
    private let server: any SiteServerControlling
    private let webEngine: any WebEngineProvisioning
    private let provisioning: any SiteProvisioning
    private let restore: any WordPressRestoring
    private let ide: any SiteIDEConfiguring
    private let routes: any APIRouteIntrospecting
    private let dns: any DNSResolverManaging
    private let runtimes: any RuntimeManaging
    private let sharing: any SiteSharing
    private let modals: KTModalPresenter
    private let sitesRoot: @MainActor () -> URL
    private let httpsByDefault: @MainActor () -> Bool
    private let route: @MainActor (SitesRoute) -> Void

    @MainActor private lazy var vm = SitesViewModel(
        catalog: catalog,
        server: server,
        webEngine: webEngine,
        runtimes: runtimes,
        sharing: sharing,
        dns: dns,
        provisioning: provisioning,
        route: route
    )

    @MainActor private let feedback = KTFeedbackCenter()

    public init(
        catalog: any SiteCatalogManaging,
        server: any SiteServerControlling,
        webEngine: any WebEngineProvisioning,
        provisioning: any SiteProvisioning,
        restore: any WordPressRestoring,
        ide: any SiteIDEConfiguring,
        routes: any APIRouteIntrospecting,
        dns: any DNSResolverManaging,
        runtimes: any RuntimeManaging,
        sharing: any SiteSharing,
        modals: KTModalPresenter,
        sitesRoot: @escaping @MainActor () -> URL,
        httpsByDefault: @escaping @MainActor () -> Bool,
        route: @escaping @MainActor (SitesRoute) -> Void
    ) {
        self.catalog = catalog
        self.server = server
        self.webEngine = webEngine
        self.provisioning = provisioning
        self.restore = restore
        self.ide = ide
        self.routes = routes
        self.dns = dns
        self.runtimes = runtimes
        self.sharing = sharing
        self.modals = modals
        self.sitesRoot = sitesRoot
        self.httpsByDefault = httpsByDefault
        self.route = route
    }

    @MainActor
    public func makeContentView() -> AnyView {
        AnyView(
            SitesScreen(
                vm: vm,
                provisioning: provisioning,
                restore: restore,
                ide: ide,
                routes: routes,
                modals: modals,
                sitesRoot: sitesRoot(),
                httpsByDefault: httpsByDefault()
            )
            .environmentObject(feedback)
        )
    }

    @MainActor
    public func sectionDidActivate() {
        vm.startNodeProbing()
    }

    @MainActor
    public func sectionDidDeactivate() {
        vm.stopNodeProbing()
    }
}
