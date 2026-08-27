import Foundation
import KTPlatformContracts
import KTStackCore

public struct DatabaseToolsService: DatabaseToolsProviding {
    private let catalog: ServiceBinaryCatalog
    private let versions: ServiceVersionStore
    private let mongoTools: MongoToolsCatalog

    public init(paths: AppSupportPaths = AppSupportPaths()) {
        let catalog = ServiceBinaryCatalog(paths: paths)
        self.catalog = catalog
        versions = ServiceVersionStore(paths: paths, catalog: catalog)
        mongoTools = MongoToolsCatalog(paths: paths)
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
        return catalog.binary(engine.serviceKind, relPath)
    }

    private func fallbackMariaDBBinary(_ relPath: String) -> URL? {
        guard !catalog.isInstalled(.mysql), catalog.isInstalled(.mariadb) else { return nil }
        return catalog.binary(.mariadb, relPath)
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
