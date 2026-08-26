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
        catalog.isInstalled(engine.serviceKind)
    }

    public func activeVersion(_ engine: DatabaseEngine) -> String? {
        versions.activeVersion(engine.serviceKind)
    }

    public func binary(_ engine: DatabaseEngine, _ relPath: String) -> URL? {
        catalog.binary(engine.serviceKind, relPath)
    }

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
