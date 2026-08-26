import Combine
import Foundation
import KTStackCore

public struct SiteRemovalCoordinator: Sendable {
    private let deleteFolder: @Sendable (Site) async throws -> Void
    private let dropDatabase: @Sendable (String) async throws -> Void
    private let removeRecord: @Sendable (Site) async -> Void

    public init(
        deleteFolder: @escaping @Sendable (Site) async throws -> Void,
        dropDatabase: @escaping @Sendable (String) async throws -> Void,
        removeRecord: @escaping @Sendable (Site) async -> Void
    ) {
        self.deleteFolder = deleteFolder
        self.dropDatabase = dropDatabase
        self.removeRecord = removeRecord
    }

    public func remove(_ site: Site) async throws {
        try await deleteFolder(site)
        if let databaseName = site.databaseName {
            try await dropDatabase(databaseName)
        }
        await removeRecord(site)
    }
}

@MainActor
public final class SiteRegistry: ObservableObject {
    @Published public private(set) var sites: [Site] = []

    /// Fired after any successful mutation (and after load), on the main actor.
    public var onChange: (() -> Void)?

    /// The single dev TLD this registry validates against (dnsmasq wildcard). Injected from
    /// `AppPreferences` at init and baked for the registry's lifetime — a change takes effect on the
    /// next launch (the registry/helper read the TLD once at startup; live re-injection is avoided).
    public let tld: String

    private let storeURL: URL
    private let inspector = SiteInspector()
    private let versionResolver = ProjectVersionResolver()
    private let preflight = PortPreflight()

    private let installedPHP: @Sendable () -> [String]

    public init(
        storeURL: URL,
        tld: String = AppPreferences.defaultTLD,
        installedPHP: @escaping @Sendable () -> [String] = { BundledPHP.plannedVersions }
    ) {
        self.storeURL = storeURL
        self.tld = tld
        self.installedPHP = installedPHP
        load()
    }

    public enum RegistryError: LocalizedError, Equatable {
        case invalidDomain(String)
        case wrongTLD(String, expected: String)
        case domainTaken(String)
        case notADirectory(String)
        case unsafeDeletePath(String)
        case noFreeBackendPort
        case proxyTargetLoopsToSite(String)
        case aliasTaken(String, by: String)
        case aliasEqualsDomain(String)
        case invalidEnv(String)
        case serverBusy

        public var errorDescription: String? {
            switch self {
            case let .invalidDomain(d): "“\(d)” is not a valid domain."
            case let .wrongTLD(d, t): "“\(d)” must end in .\(t) (MVP resolves only .\(t) automatically)."
            case let .domainTaken(d): "Another site already uses “\(d)”."
            case let .notADirectory(p): "“\(p)” is not a folder."
            case let .unsafeDeletePath(p): "Refusing to delete unsafe site folder “\(p)”."
            case .noFreeBackendPort: "No free loopback port in 4000-4999 for a site backend."
            case let .proxyTargetLoopsToSite(d): "The target cannot point back at this site (\(d))."
            case let .aliasTaken(a, owner): "“\(a)” is already used by “\(owner)”."
            case let .aliasEqualsDomain(a): "“\(a)” is already the site's main domain."
            case let .invalidEnv(k): "“\(k)” is not a valid environment variable."
            case .serverBusy: "The server is busy, try again in a moment."
            }
        }
    }

    @discardableResult
    public func add(
        folder: URL,
        phpVersion: String = BundledPHP.defaultVersion,
        respectProjectMarkers: Bool = true,
        databaseName: String? = nil
    ) throws -> Site {
        var isDir: ObjCBool = false
        guard FileManager.default.fileExists(atPath: folder.path, isDirectory: &isDir), isDir.boolValue else {
            throw RegistryError.notADirectory(folder.path)
        }
        let info = inspector.inspect(folder: folder, tld: tld)
        let domain = uniqueDomain(info.defaultDomain)

        let resolvedPHP = respectProjectMarkers
            ? resolveInitialPHP(folder: folder, fallback: phpVersion)
            : (knownPHPVersions().contains(phpVersion) ? phpVersion : (knownPHPVersions().first ?? BundledPHP.defaultVersion))
        var site = Site(
            name: folder.lastPathComponent,
            path: folder.path,
            docroot: info.docroot.path,
            domain: domain,
            phpVersion: resolvedPHP,
            type: info.type,
            databaseName: databaseName
        )
        if info.type == .node { site.nodePort = nextFreeNodePort() }
        // PHP sites route through a loopback backend; static/node are front-served, no port.
        if info.type == .php { site.backendPort = try? nextFreeBackendPort() }
        sites.append(site)
        persist()
        return site
    }

    // Proxy site không có thư mục: path/docroot rỗng, không cấp nodePort/backendPort.
    @discardableResult
    public func addProxy(name: String, domain: String, target: ProxyTarget) throws -> Site {
        try validateDomain(domain)
        let site = Site(
            name: name,
            path: "",
            docroot: "",
            domain: domain,
            phpVersion: BundledPHP.defaultVersion,
            type: .proxy,
            proxyTarget: target.upstreamURLString
        )
        sites.append(site)
        persist()
        return site
    }

    public func setProxyTarget(_ site: Site, _ target: ProxyTarget) {
        update(site.id) { $0.proxyTarget = target.upstreamURLString }
    }

    // Chặn upstream trỏ về chính domain của site (vòng lặp qua front nginx).
    public func validateProxyTarget(_ target: ProxyTarget, for site: Site?) throws {
        if let site, target.host == site.domain {
            throw RegistryError.proxyTargetLoopsToSite(site.domain)
        }
    }

    public func nextFreeNodePort() -> Int {
        let used = Set(sites.compactMap(\.nodePort))
        let reserved: Set = [3306, 5432, 6379, 8025, 27017]
        for port in 3000...3999 where !used.contains(port) && !reserved.contains(port) {
            return port
        }
        return 3000
    }

    /// Backend range 4000-4999 is disjoint from Node (3000-3999) and the reserved DB ports.
    /// Probes the OS so a port a non-KTStack process already holds is skipped, not handed out.
    public func nextFreeBackendPort() throws -> Int {
        let used = Set(sites.compactMap(\.backendPort))
        for port in 4000...4999 where !used.contains(port) {
            if case .available = preflight.check(port: port) { return port }
        }
        throw RegistryError.noFreeBackendPort
    }

    /// Old installs decode with backendPort == nil; assign one to every PHP site lacking it
    /// before the front renders, else the front would proxy_pass to an empty port.
    @discardableResult
    public func assignBackendPortsIfNeeded() -> Bool {
        var changed = false
        for idx in sites.indices where sites[idx].type == .php && sites[idx].backendPort == nil {
            guard let port = try? nextFreeBackendPort() else { break }
            sites[idx].backendPort = port
            changed = true
        }
        if changed { persist() }
        return changed
    }

    public func remove(_ site: Site) {
        sites.removeAll { $0.id == site.id }
        persist()
    }

    public func removeDeletingFolder(_ site: Site) throws {
        try deleteFolderForRemoval(site)
        remove(site)
    }

    public func validateCanRemoveFolder(_ site: Site) throws {
        let folder = URL(fileURLWithPath: site.path, isDirectory: true).standardizedFileURL
        try validateDeletableSiteFolder(folder)
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: folder.path, isDirectory: &isDirectory) else { return }
        guard isDirectory.boolValue else { throw RegistryError.notADirectory(folder.path) }
    }

    public func deleteFolderForRemoval(_ site: Site) throws {
        let folder = URL(fileURLWithPath: site.path, isDirectory: true).standardizedFileURL
        try validateCanRemoveFolder(site)
        guard FileManager.default.fileExists(atPath: folder.path) else { return }
        try FileManager.default.removeItem(at: folder)
    }

    public func editDomain(_ site: Site, to newDomain: String) throws {
        let domain = newDomain.trimmingCharacters(in: .whitespaces).lowercased()
        try validateDomain(domain, excluding: site.id)
        update(site.id) { $0.domain = domain }
    }

    /// Đổi TLD toàn cục: rewrite suffix mọi domain .old→.new. Không qua validateDomain (registry.tld
    /// vẫn là old tới lúc relaunch); label vốn đã unique nên swap suffix không tạo trùng.
    @discardableResult
    public func migrateTLD(from old: String, to new: String) -> [Site] {
        let suffix = ".\(old)"
        func rewrite(_ host: String) -> String {
            host.hasSuffix(suffix) ? "\(host.dropLast(suffix.count)).\(new)" : host
        }
        var migrated: [Site] = []
        for idx in sites.indices {
            var changed = false
            if sites[idx].domain.hasSuffix(suffix) {
                sites[idx].domain = rewrite(sites[idx].domain)
                changed = true
            }
            let newAliases = sites[idx].aliases.map(rewrite)
            if newAliases != sites[idx].aliases {
                sites[idx].aliases = newAliases
                changed = true
            }
            if changed { migrated.append(sites[idx]) }
        }
        if !migrated.isEmpty { persist() }
        return migrated
    }

    public func setPHPVersion(_ site: Site, to version: String) {
        guard knownPHPVersions().contains(version) else { return }
        update(site.id) { $0.phpVersion = version }
    }

    public func setDatabaseName(_ site: Site, _ name: String?) {
        update(site.id) { $0.databaseName = name }
    }

    private func knownPHPVersions() -> [String] {
        let installed = installedPHP()
        return installed.isEmpty ? [BundledPHP.defaultVersion] : installed
    }

    private func resolveInitialPHP(folder: URL, fallback: String) -> String {
        let known = knownPHPVersions()
        return versionResolver.selectVersion(.php, forProjectAt: folder, installed: known, preferred: fallback)
            ?? (known.first ?? BundledPHP.defaultVersion)
    }

    public func setSecure(_ site: Site, _ secure: Bool) {
        update(site.id) { $0.secure = secure }
    }

    public func setNodePort(_ site: Site, _ port: Int?) {
        update(site.id) { $0.nodePort = port }
    }

    // PHP-only: static/node are front-served and have no per-site engine. Triggers a reconcile
    // (onChange) that rewrites the backend config and switches that one site's backend process.
    public func setServerEngine(_ site: Site, _ engine: WebServerEngine) {
        guard site.type == .php else { return }
        update(site.id) { $0.serverEngine = engine }
    }

    /// Atomic engine+port change for a zero-downtime swap: the new engine gets a fresh backendPort
    /// so it can come up alongside the old one. One update so a decode never sees engine≠port.
    public func setEngineAndPort(_ id: UUID, engine: WebServerEngine, port: Int) {
        update(id) { $0.serverEngine = engine; $0.backendPort = port }
    }

    public func reinspect(_ site: Site) {
        let info = inspector.inspect(folder: URL(fileURLWithPath: site.path), tld: tld)
        guard info.docroot.path != site.docroot || info.type != site.type else { return }
        update(site.id) { $0.docroot = info.docroot.path; $0.type = info.type }
    }

    public func validateDomain(_ domain: String, excluding id: UUID? = nil) throws {
        guard NginxConfigWriter.isValidDomain(domain) else { throw RegistryError.invalidDomain(domain) }
        guard domain.hasSuffix(".\(tld)"), domain.count > tld.count + 1 else {
            throw RegistryError.wrongTLD(domain, expected: tld)
        }
        if sites.contains(where: { ($0.domain == domain || $0.aliases.contains(domain)) && $0.id != id }) {
            throw RegistryError.domainTaken(domain)
        }
    }

    private func normalizeAlias(_ alias: String) -> String {
        alias.trimmingCharacters(in: .whitespaces).lowercased()
    }

    // Validate danh sách alias user nhập; plugin gọi để báo inline, registry gọi khi ghi.
    public func validateAliases(_ aliases: [String], for site: Site) throws {
        var seen = Set<String>()
        for raw in aliases {
            let alias = normalizeAlias(raw)
            guard NginxConfigWriter.isValidDomain(alias) else { throw RegistryError.invalidDomain(alias) }
            guard alias.hasSuffix(".\(tld)"), alias.count > tld.count + 1 else {
                throw RegistryError.wrongTLD(alias, expected: tld)
            }
            guard alias != site.domain else { throw RegistryError.aliasEqualsDomain(alias) }
            guard seen.insert(alias).inserted else { throw RegistryError.aliasTaken(alias, by: site.domain) }
            if let owner = sites.first(where: {
                $0.id != site.id && ($0.domain == alias || $0.aliases.contains(alias))
            }) {
                throw RegistryError.aliasTaken(alias, by: owner.domain)
            }
        }
    }

    public func setAliases(_ site: Site, _ aliases: [String]) throws {
        try validateAliases(aliases, for: site)
        let normalized = aliases.map(normalizeAlias)
        update(site.id) { $0.aliases = normalized }
    }

    public func setEnvVars(_ site: Site, _ env: [String: String]) throws {
        if let err = SiteEnvVars.validate(env) { throw RegistryError.invalidEnv(Self.envErrorKey(err)) }
        update(site.id) { $0.envVars = env }
    }

    // Không validate ở đây: nginx -t chạy ở controller trước khi persist (fail-closed).
    public func setFrontDirectives(_ site: Site, _ text: String?) {
        update(site.id) { $0.frontDirectives = text }
    }

    private static func envErrorKey(_ error: SiteEnvVarError) -> String {
        switch error {
        case let .invalidKey(k), let .reservedKey(k), let .invalidValue(k): k
        }
    }

    private func update(_ id: UUID, _ mutate: (inout Site) -> Void) {
        guard let idx = sites.firstIndex(where: { $0.id == id }) else { return }
        mutate(&sites[idx])
        persist()
    }

    private func validateDeletableSiteFolder(_ folder: URL) throws {
        let path = folder.path
        let home = FileManager.default.homeDirectoryForCurrentUser.standardizedFileURL.path
        guard path != "/", path != home, !folder.lastPathComponent.isEmpty else {
            throw RegistryError.unsafeDeletePath(path)
        }
    }

    // domain hoặc alias của bất kỳ site nào đang chiếm tên này.
    private func isDomainInUse(_ candidate: String) -> Bool {
        sites.contains { $0.domain == candidate || $0.aliases.contains(candidate) }
    }

    private func uniqueDomain(_ base: String) -> String {
        guard isDomainInUse(base) else { return base }
        // base = "<label>.test" → insert "-N" before the TLD.
        let label = base.replacingOccurrences(of: ".\(tld)", with: "")
        var n = 2
        while isDomainInUse("\(label)-\(n).\(tld)") {
            n += 1
        }
        return "\(label)-\(n).\(tld)"
    }

    private func load() {
        guard let data = try? Data(contentsOf: storeURL) else { return } // absent file → fresh
        if let decoded = try? JSONDecoder().decode([Site].self, from: data) {
            sites = decoded
        } else {
            let backup = storeURL.appendingPathExtension("bak")
            try? FileManager.default.removeItem(at: backup)
            try? FileManager.default.copyItem(at: storeURL, to: backup)
            NSLog("KTStack: could not decode site registry; backed up to \(backup.lastPathComponent)")
        }
        onChange?()
    }

    private func persist() {
        do {
            try FileManager.default.createDirectory(
                at: storeURL.deletingLastPathComponent(),
                withIntermediateDirectories: true,
                attributes: [.posixPermissions: 0o700]
            )
            let data = try JSONEncoder().encode(sites)
            try data.write(to: storeURL, options: .atomic)
        } catch {
            NSLog("KTStack: failed to persist site registry: \(error.localizedDescription)")
        }
        onChange?()
    }
}
