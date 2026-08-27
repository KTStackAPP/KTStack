import Combine
import Foundation
import KTStackCore

@MainActor
public final class ServiceManager: ObservableObject {
    public static let order: [ServiceKind] = [.nginx, .phpFpm, .dnsmasq, .mysql, .mariadb, .postgres, .redis, .memcached, .mongodb, .mailpit]
    static let dbCacheKinds: Set<ServiceKind> = [.mysql, .mariadb, .postgres, .redis, .memcached, .mongodb]
    // On-demand engine (không phải web front): Start/Stop/Restart All lặp qua đây.
    static let onDemandKinds: [ServiceKind] = [.mysql, .mariadb, .postgres, .redis, .memcached, .mongodb, .mailpit]

    @Published public internal(set) var snapshots: [ServiceSnapshot] = []

    let server: LocalServerController
    let dns: DNSAutomationService
    let paths: AppSupportPaths
    let agents: LaunchAgentManager

    var services: [ServiceKind: ManagedService] = [:]
    let restart = RestartPolicy()
    var busy: Set<ServiceKind> = []
    var pollTask: Task<Void, Never>?
    // Số view đang hiển thị trạng thái service; 0 → poll chậm và bỏ qua sampler `ps`.
    var liveUpdateClients = 0
    var fastPollInterval: TimeInterval = 0.9

    let catalog: ServiceBinaryCatalog
    let downloader: RuntimeDownloader
    let metricsSampler = ServiceMetricsSampler()
    var downloadFraction: [String: Double] = [:]
    var installError: [String: String] = [:]
    var installTasks: [String: Task<Void, Never>] = [:]
    var cancellables = Set<AnyCancellable>()
    var versionStore: ServiceVersionStore

    public init(
        server: LocalServerController,
        dns: DNSAutomationService,
        paths: AppSupportPaths = AppSupportPaths()
    ) {
        self.server = server
        self.dns = dns
        self.paths = paths
        let agents = LaunchAgentManager(paths: paths)
        self.agents = agents
        let cat = ServiceBinaryCatalog(paths: paths)
        catalog = cat
        downloader = RuntimeDownloader(paths: paths)
        versionStore = ServiceVersionStore(paths: paths, catalog: cat)
        ServiceDataRelocation.runIfNeeded(paths: paths, catalog: cat)

        let mysqlProvider: () -> String? = {
            ServiceVersionStore(paths: paths, catalog: ServiceBinaryCatalog(paths: paths)).activeVersion(.mysql)
        }
        let postgresProvider: () -> String? = {
            ServiceVersionStore(paths: paths, catalog: ServiceBinaryCatalog(paths: paths)).activeVersion(.postgres)
        }
        let redisProvider: () -> String? = {
            ServiceVersionStore(paths: paths, catalog: ServiceBinaryCatalog(paths: paths)).activeVersion(.redis)
        }
        let mongoProvider: () -> String? = {
            ServiceVersionStore(paths: paths, catalog: ServiceBinaryCatalog(paths: paths)).activeVersion(.mongodb)
        }
        let mariadbProvider: () -> String? = {
            ServiceVersionStore(paths: paths, catalog: ServiceBinaryCatalog(paths: paths)).activeVersion(.mariadb)
        }
        let memcachedProvider: () -> String? = {
            ServiceVersionStore(paths: paths, catalog: ServiceBinaryCatalog(paths: paths)).activeVersion(.memcached)
        }
        services = [
            .dnsmasq: DnsmasqProxyService(dns: dns),
            .mysql: MySQLController(paths: paths, agents: agents, activeVersion: mysqlProvider),
            .mariadb: MySQLController(paths: paths, agents: agents, activeVersion: mariadbProvider, flavor: .mariadb),
            .postgres: PostgreSQLController(paths: paths, agents: agents, activeVersion: postgresProvider),
            .redis: RedisController(paths: paths, agents: agents, activeVersion: redisProvider),
            .memcached: MemcachedController(paths: paths, agents: agents, activeVersion: memcachedProvider),
            .mongodb: MongoDBController(paths: paths, agents: agents, activeVersion: mongoProvider),
            .mailpit: MailpitController(paths: paths, agents: agents),
        ]
        snapshots = Self.order.map { ServiceSnapshot(kind: $0, status: .stopped, detail: "", isInstalled: true) }

        server.objectWillChange
            .merge(with: dns.objectWillChange)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in self?.syncControllerSnapshots() }
            .store(in: &cancellables)
    }

    private func syncControllerSnapshots() {
        guard !snapshots.isEmpty else { return }
        replaceSnapshot(webSnapshot(
            .nginx,
            status: server.nginxStatus,
            detail: server.isRunning ? ":80/:443" : "off"
        ))
        replaceSnapshot(webSnapshot(.phpFpm, status: server.phpStatus, detail: phpDetail()))
    }

    private func replaceSnapshot(_ snap: ServiceSnapshot) {
        if let i = snapshots.firstIndex(where: { $0.kind == snap.kind }), snapshots[i] != snap {
            snapshots[i] = snap
        }
    }

    func webSnapshot(_ kind: ServiceKind, status: ServiceStatus, detail: String) -> ServiceSnapshot {
        ServiceSnapshot(
            kind: kind,
            status: status,
            detail: detail,
            isInstalled: true,
            isBusy: status == .starting || status == .stopping,
            errorMessage: nil
        )
    }

    func phpDetail() -> String {
        server.isRunning ? server.availableVersions.joined(separator: ", ") : "off"
    }

    func snapshot(_ kind: ServiceKind) -> ServiceSnapshot? {
        snapshots.first { $0.kind == kind }
    }

    func lastErrorMessage(_ kind: ServiceKind) -> String {
        "\(kind.displayName) kept crashing on restart. Restart it manually or check its logs."
    }

    func setSnapshotBusy(_ kind: ServiceKind, _ isBusy: Bool, errorMessage: String? = nil) {
        guard let idx = snapshots.firstIndex(where: { $0.kind == kind }) else { return }
        snapshots[idx].isBusy = isBusy
        if let errorMessage { snapshots[idx].errorMessage = errorMessage }
    }
}
