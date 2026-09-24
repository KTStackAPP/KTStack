import Foundation

public extension SiteRegistry {
    func applyRestore(_ site: Site, database: String?, phpVersion: String) {
        setDatabaseName(site, database)
        setPHPVersion(site, to: phpVersion)
        _ = reinspect(site)
    }
}
