import Foundation
import KTPlatformContracts
import KTStackCore

public struct DatabaseToolsService: DatabaseToolsProviding {
    private let paths: AppSupportPaths
    private let catalog: ServiceBinaryCatalog
    private let mongoTools: MongoToolsCatalog

    public init(paths: AppSupportPaths = AppSupportPaths()) {
        self.paths = paths
        catalog = ServiceBinaryCatalog(paths: paths)
        mongoTools = MongoToolsCatalog(paths: paths)
    }

    private var versions: ServiceVersionStore {
        ServiceVersionStore(paths: paths, catalog: catalog)
    }

    public func isInstalled(_ engine: DatabaseEngine) -> Bool {
        // DatabaseEngine.mysql phục vụ cả họ 3306: MariaDB đứng thay khi MySQL chưa cài.
        if engine == .mysql, !catalog.isInstalled(.mysql) {
            return catalog.isInstalled(.mariadb)
        }
        return catalog.isInstalled(engine.serviceKind)
    }

    public func activeVersion(_ engine: DatabaseEngine) -> String? {
        if engine == .mysql, versions.activeVersion(.mysql) == nil {
            return versions.activeVersion(.mariadb)
        }
        return versions.activeVersion(engine.serviceKind)
    }

    public func binary(_ engine: DatabaseEngine, _ relPath: String) -> URL? {
        // MariaDB tree ships bin/mysql -> mariadb symlink, nên cùng relPath resolve được client.
        if engine == .mysql, let mariadb = fallbackMariaDBBinary(relPath) {
            return mariadb
        }
        return activeBinary(engine.serviceKind, relPath)
    }

    private func fallbackMariaDBBinary(_ relPath: String) -> URL? {
        guard !catalog.isInstalled(.mysql), catalog.isInstalled(.mariadb) else { return nil }
        return activeBinary(.mariadb, relPath)
    }

    private func activeBinary(_ kind: ServiceKind, _ relPath: String) -> URL? {
        guard let version = versions.activeVersion(kind) else { return nil }
        return catalog.binary(kind, relPath, version: version)
    }

    // Không fallback sang MariaDB: version string hai flavor không trùng nhau nên pin theo version chỉ hợp lệ cho MySQL.
    public func binary(_ engine: DatabaseEngine, _ relPath: String, version: String) -> URL? {
        catalog.binary(engine.serviceKind, relPath, version: version)
    }

    public var mongoToolsInstalled: Bool { mongoTools.isInstalled }

    public func mongoToolsBinary(_ relPath: String) -> URL? { mongoTools.binary(relPath) }
}

extension DatabaseEngine {
    var serviceKind: ServiceKind {
        switch self {
        case .mysql: .mysql
        case .postgres: .postgres
        case .mongodb: .mongodb
        }
    }
}
