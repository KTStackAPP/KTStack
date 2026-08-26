import Foundation
import KTPlatformContracts
import KTStackCore

enum SiteActionError: LocalizedError {
    case duplicateNodePort(port: Int, domain: String)

    var errorDescription: String? {
        switch self {
        case let .duplicateNodePort(port, domain):
            "Port \(port) is already used by \(domain). Each Node site needs its own port."
        }
    }
}

@MainActor
final class SitesViewModel: ObservableObject {
    @Published private(set) var sites: [SiteSummary] = []
    @Published private(set) var tld: String
    @Published private(set) var server: SiteServerState
    @Published private(set) var webEngine: WebEngineState
    @Published private(set) var runtimes: RuntimeState
    @Published private(set) var shares: [UUID: SiteShareState] = [:]
    @Published private(set) var dns: DNSResolverState
    @Published var nodeRunning: [UUID: Bool] = [:]
    @Published var frameworks: [UUID: PHPFramework] = [:]

    let catalog: any SiteCatalogManaging
    let serverControl: any SiteServerControlling
    let webEngineManager: any WebEngineProvisioning
    let runtimesManager: any RuntimeManaging
    let sharingManager: any SiteSharing
    let dnsManager: any DNSResolverManaging
    let provisioning: any SiteProvisioning
    let route: @MainActor (SitesRoute) -> Void

    private var tasks: [Task<Void, Never>] = []
    var probeTask: Task<Void, Never>?

    var defaultPHP: String {
        runtimes.defaults[.php] ?? server.phpVersions.last ?? "8.4"
    }

    init(
        catalog: any SiteCatalogManaging,
        server: any SiteServerControlling,
        webEngine: any WebEngineProvisioning,
        runtimes: any RuntimeManaging,
        sharing: any SiteSharing,
        dns: any DNSResolverManaging,
        provisioning: any SiteProvisioning,
        route: @escaping @MainActor (SitesRoute) -> Void
    ) {
        self.catalog = catalog
        serverControl = server
        webEngineManager = webEngine
        runtimesManager = runtimes
        sharingManager = sharing
        dnsManager = dns
        self.provisioning = provisioning
        self.route = route

        sites = catalog.catalog.sites
        tld = catalog.catalog.tld
        self.server = server.serverState
        self.webEngine = webEngine.webEngineState
        self.runtimes = runtimes.state
        shares = sharing.shareStates
        self.dns = dns.dnsState

        tasks.append(Task { [weak self] in
            for await next in catalog.catalogStream() {
                guard let self else { return }
                sites = next.sites
                tld = next.tld
                await refreshFrameworks()
            }
        })
        tasks.append(Task { [weak self] in
            for await next in server.serverStates() { self?.server = next }
        })
        tasks.append(Task { [weak self] in
            for await next in webEngine.webEngineStates() { self?.webEngine = next }
        })
        tasks.append(Task { [weak self] in
            for await next in runtimes.states() { self?.runtimes = next }
        })
        tasks.append(Task { [weak self] in
            for await next in sharing.shareStateStream() { self?.shares = next }
        })
        tasks.append(Task { [weak self] in
            for await next in dns.dnsStates() { self?.dns = next }
        })
    }

    deinit {
        for task in tasks { task.cancel() }
        probeTask?.cancel()
    }
}
