import Foundation
import KTStackCore

// MySQL và MariaDB chia nhau port 3306. Đảm bảo "một engine họ 3306 đang chạy" cho Sites provisioning:
// nếu 3306 đã có ai đó phục vụ thì thôi, else start MySQL nếu cài, else MariaDB.
public struct SQLFamily: Sendable {
    public static let kinds: [ServiceKind] = [.mysql, .mariadb]

    public static func other(_ kind: ServiceKind) -> ServiceKind? {
        switch kind {
        case .mysql: .mariadb
        case .mariadb: .mysql
        default: nil
        }
    }

    private let paths: AppSupportPaths
    private let agents: LaunchAgentManager
    private let catalog: ServiceBinaryCatalog

    public init(paths: AppSupportPaths, agents: LaunchAgentManager) {
        self.paths = paths
        self.agents = agents
        catalog = ServiceBinaryCatalog(paths: paths)
    }

    public func ensureRunning() async throws {
        if await UpstreamProbe().probe(host: "127.0.0.1", port: 3306) == .running { return }
        guard let kind = Self.preferredKind(catalog: catalog) else { throw ServiceNotInstalled(.mysql) }
        let paths = paths, catalog = catalog
        let active: () -> String? = { ServiceVersionStore(paths: paths, catalog: catalog).activeVersion(kind) }
        let flavor: MySQLFlavor = kind == .mariadb ? .mariadb : .mysql
        try await MySQLController(paths: paths, agents: agents, activeVersion: active, flavor: flavor).start()
    }

    public static func preferredKind(catalog: ServiceBinaryCatalog) -> ServiceKind? {
        if catalog.isInstalled(.mysql) { return .mysql }
        if catalog.isInstalled(.mariadb) { return .mariadb }
        return nil
    }
}
