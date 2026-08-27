import Foundation
import KTPlatformContracts
import SwiftUI

@MainActor
final class ServicesViewModel: ObservableObject {
    struct DBEntry: Identifiable {
        let state: ServiceState
        let installed: [String]
        let active: String?
        var id: ServiceID { state.id }
    }

    @Published private(set) var services: [ServiceState]
    @Published private(set) var engines: [ServiceEngineSnapshot]
    @Published private(set) var dns: DNSResolverState
    @Published private(set) var ca: CATrustState

    static let groups: [(title: String, ids: [ServiceID])] = [
        ("Core Proxy & DNS", [.nginx, .dnsmasq]),
        ("Runtimes", [.phpFpm]),
        ("Mail", [.mailpit]),
    ]

    static let dbIDs: [ServiceID] = [.mysql, .mariadb, .postgres, .redis, .memcached, .mongodb]

    private let servicesManager: any ServiceManaging
    private let enginesManager: any ServiceEngineVersionManaging
    private let dnsManager: any DNSResolverManaging
    private let caProvider: any CATrustProviding
    private var tasks: [Task<Void, Never>] = []

    init(
        services: any ServiceManaging,
        engines: any ServiceEngineVersionManaging,
        dns: any DNSResolverManaging,
        caTrust: any CATrustProviding
    ) {
        servicesManager = services
        enginesManager = engines
        dnsManager = dns
        caProvider = caTrust
        self.services = services.serviceStates
        self.engines = engines.engineSnapshots
        self.dns = dns.dnsState
        ca = caTrust.caTrustState

        tasks.append(Task { [weak self] in
            for await next in services.serviceStateStream() { self?.services = next }
        })
        tasks.append(Task { [weak self] in
            for await next in engines.engineSnapshotStream() { self?.engines = next }
        })
        tasks.append(Task { [weak self] in
            for await next in dns.dnsStates() { self?.dns = next }
        })
        tasks.append(Task { [weak self] in
            for await next in caTrust.caTrustStates() { self?.ca = next }
        })
    }

    deinit {
        for task in tasks { task.cancel() }
    }

    func rows(for ids: [ServiceID]) -> [ServiceState] {
        services.filter { ids.contains($0.id) }
    }

    var dbEntries: [DBEntry] {
        Self.dbIDs.compactMap { id in
            guard let state = services.first(where: { $0.id == id }) else { return nil }
            let snapshot = engines.first { $0.engine == id.engine }
            return DBEntry(state: state, installed: snapshot?.installed ?? [], active: snapshot?.active)
        }
    }

    func metricsText(_ id: ServiceID) -> String? {
        services.first { $0.id == id }?.metricsText
    }

    func banners(actions: ServiceBannerActions) -> [ServiceBanner] {
        ServicesBannerBuilder.banners(services: services, dns: dns, ca: ca, actions: actions)
    }

    func toggle(_ id: ServiceID) { servicesManager.toggle(id) }
    func restart(_ id: ServiceID) { servicesManager.restart(id) }
    func install(_ id: ServiceID) { servicesManager.install(id) }
    func cancelInstall(_ id: ServiceID) { servicesManager.cancelInstall(id) }
    func resetData(_ id: ServiceID) { servicesManager.resetData(id) }
    func startAll() { servicesManager.startAll() }
    func restartAll() { servicesManager.restartAll() }

    func setActive(_ id: ServiceID, version: String) -> Result<Void, Error> {
        guard let engine = id.engine else {
            return .failure(ServicesError.noEngine)
        }
        return Result { try enginesManager.setActiveVersion(engine, version: version) }
    }

    func enableDNS() { dnsManager.enable() }
    func resetDNS() { dnsManager.reset() }
    func refreshDNS() { dnsManager.refresh() }
    func refreshCATrust() async { await caProvider.refreshTrust() }

    static func logSourceID(_ id: ServiceID) -> String? {
        switch id {
        case .nginx: "nginx-error"
        case .mysql: "mysql"
        case .mariadb: "mariadb"
        case .postgres: "postgres"
        case .redis: "redis"
        case .memcached: "memcached"
        case .mongodb: "mongodb"
        case .mailpit: "mailpit"
        case .phpFpm, .dnsmasq: nil
        }
    }
}

enum ServicesError: Error {
    case noEngine
}
