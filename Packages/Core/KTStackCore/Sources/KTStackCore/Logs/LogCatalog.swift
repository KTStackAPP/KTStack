import Foundation

public struct LogSource: Identifiable, Sendable, Hashable {
    public enum Kind: String, Sendable { case service, site }
    public let id: String
    public let displayName: String
    public let kind: Kind
    public let url: URL
}

public struct LogCatalog: Sendable {
    private let paths: AppSupportPaths
    public init(paths: AppSupportPaths) {
        self.paths = paths
    }

    public func sources(siteDomains: [String], phpVersions: [String]) -> [LogSource] {
        let fm = FileManager.default
        var out: [LogSource] = [
            LogSource(id: "nginx-error", displayName: "Nginx · error", kind: .service, url: paths.nginxErrorLog),
            LogSource(id: "nginx-access", displayName: "Nginx · access", kind: .service, url: paths.nginxAccessLog),
        ]
        for v in phpVersions.sorted() {
            out.append(LogSource(id: "php-\(v)", displayName: "PHP-FPM \(v)", kind: .service, url: paths.phpFpmLog(v)))
        }
        for svc in ["mysql", "mariadb", "postgres", "redis", "memcached", "mongodb", "mailpit"] {
            let url = paths.serviceLog(svc)
            if fm.fileExists(atPath: url.path) {
                out.append(LogSource(id: svc, displayName: svc.capitalized, kind: .service, url: url))
            }
        }
        let diagURL = paths.serviceLog("diagnostics")
        if fm.fileExists(atPath: diagURL.path) {
            out.append(LogSource(id: "diagnostics", displayName: "Diagnostics", kind: .service, url: diagURL))
        }
        for domain in siteDomains.sorted() {
            for (suffix, label, url) in [
                ("access", "access", paths.siteAccessLog(domain)),
                ("error", "error", paths.siteErrorLog(domain)),
            ] {
                if fm.fileExists(atPath: url.path) {
                    out.append(LogSource(
                        id: "site-\(domain)-\(suffix)",
                        displayName: "\(domain) · \(label)",
                        kind: .site,
                        url: url
                    ))
                }
            }
            out += workerSources(domain: domain)
        }
        return out
    }

    public static func siteWorkerSourceID(domain: String, worker: String) -> String {
        "site-\(domain)-worker-\(worker)"
    }

    private func workerSources(domain: String) -> [LogSource] {
        let prefix = "\(domain).worker-"
        let files = (try? FileManager.default.contentsOfDirectory(atPath: paths.logsSites.path)) ?? []
        return files.filter { $0.hasPrefix(prefix) && $0.hasSuffix(".log") }.sorted().compactMap { file in
            let worker = String(file.dropFirst(prefix.count).dropLast(".log".count))
            guard SiteWorkers.isValidName(worker) else { return nil }
            return LogSource(
                id: Self.siteWorkerSourceID(domain: domain, worker: worker),
                displayName: "\(domain) · worker \(worker)",
                kind: .site,
                url: paths.siteWorkerLog(domain, worker: worker)
            )
        }
    }
}
