import Foundation
import KTPlatformContracts

public final class PlatformBackupEnvironment: BackupRuntimeEnvironment, @unchecked Sendable {
    private let engines: any DatabaseEngineManaging
    private let siteCatalog: any SiteCatalogManaging

    public init(engines: any DatabaseEngineManaging, siteCatalog: any SiteCatalogManaging) {
        self.engines = engines
        self.siteCatalog = siteCatalog
    }

    public func runningEngines() async -> Set<DatabaseEngine> {
        await MainActor.run { Set(DatabaseEngine.allCases.filter { self.engines.isRunning($0) }) }
    }

    public func siteFolders(_ ids: [UUID]) async -> [BackupSiteFolder] {
        await MainActor.run {
            self.siteCatalog.catalog.sites.filter { ids.contains($0.id) }.map {
                BackupSiteFolder(id: $0.id, name: $0.name, root: URL(fileURLWithPath: $0.path, isDirectory: true))
            }
        }
    }

    @MainActor
    public var sites: [SiteSummary] {
        siteCatalog.catalog.sites
    }
}
