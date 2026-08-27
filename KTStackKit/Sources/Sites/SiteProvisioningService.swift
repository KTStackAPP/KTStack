import Foundation
import KTPlatformContracts
import KTStackCore

// Gom orchestration install/import/remove/restore/IDE về platform (fail-closed, mẫu PHPConfigService/
// NginxIncludeService). Plugin chỉ drive UI state; service dựng MySQLController/SiteHTTPSProvisioner/
// installers, không lộ ra plugin. Thứ tự và rollback giữ nguyên như NewSiteModel/RestoreBackupModel cũ.
public final class SiteProvisioningService: SiteProvisioning, WordPressRestoring, SiteIDEConfiguring {
    private let registry: SiteRegistry
    private let installService: SiteInstallService
    private let databaseExists: @Sendable (String) async throws -> Bool
    private let createDatabase: @Sendable (String) async throws -> Void
    private let dropDatabase: @Sendable (String) async throws -> Void
    private let ensureSeededIni: @Sendable (String) throws -> Void
    private let makeInstaller: @Sendable (NewSiteRequest) async throws -> SiteInstaller
    private let enableHTTPSForSite: @Sendable (Site) async throws -> Void
    private let performRestore: @Sendable @MainActor (
        _ site: Site, _ request: RestoreRequest, _ emit: @escaping @Sendable (RestoreEvent) -> Void
    ) async throws -> RestoreOutcome
    private let resolveSafeDocroot: @Sendable (URL) throws -> URL
    private let inspector: SiteInspector
    private let scanner: SiteScanner
    private let ideWriter: IDEDebugConfigWriter

    init(
        registry: SiteRegistry,
        database: DatabaseProvisioner,
        databaseExists: @escaping @Sendable (String) async throws -> Bool,
        createDatabase: @escaping @Sendable (String) async throws -> Void,
        dropDatabase: @escaping @Sendable (String) async throws -> Void,
        ensureSeededIni: @escaping @Sendable (String) throws -> Void,
        makeInstaller: @escaping @Sendable (NewSiteRequest) async throws -> SiteInstaller,
        enableHTTPSForSite: @escaping @Sendable (Site) async throws -> Void,
        performRestore: @escaping @Sendable @MainActor (Site, RestoreRequest, @escaping @Sendable (RestoreEvent) -> Void) async throws -> RestoreOutcome,
        resolveSafeDocroot: @escaping @Sendable (URL) throws -> URL = { try ImportSafety.resolvedSafeDocroot($0) },
        inspector: SiteInspector = SiteInspector(),
        scanner: SiteScanner = SiteScanner(),
        ideWriter: IDEDebugConfigWriter = IDEDebugConfigWriter()
    ) {
        self.registry = registry
        installService = SiteInstallService(database: database)
        self.databaseExists = databaseExists
        self.createDatabase = createDatabase
        self.dropDatabase = dropDatabase
        self.ensureSeededIni = ensureSeededIni
        self.makeInstaller = makeInstaller
        self.enableHTTPSForSite = enableHTTPSForSite
        self.performRestore = performRestore
        self.resolveSafeDocroot = resolveSafeDocroot
        self.inspector = inspector
        self.scanner = scanner
        self.ideWriter = ideWriter
    }

    public convenience init(paths: AppSupportPaths = AppSupportPaths(), server: LocalServerController) {
        let registry = server.registry
        let sqlFamily = SQLFamily(paths: paths, agents: LaunchAgentManager(paths: paths))
        let ensureEngine: @Sendable () async throws -> Void = { try await sqlFamily.ensureRunning() }
        let database = DatabaseProvisioner(ensureEngine: ensureEngine)
        let mkcert = MkcertRunner(mkcert: paths.mkcertBinary, caroot: paths.caDir)
        let httpsProvisioner = SiteHTTPSProvisioner(
            paths: paths,
            tld: registry.tld,
            mkcert: mkcert,
            certMinter: CertMinter(paths: paths, runner: MkcertRunner(mkcert: paths.mkcertBinary, caroot: paths.caDir))
        )
        let iniStore = PHPIniStore(paths: paths)

        self.init(
            registry: registry,
            database: database,
            databaseExists: { try await database.exists($0) },
            createDatabase: { try await database.createDatabase($0) },
            dropDatabase: { try await database.dropDatabase($0) },
            ensureSeededIni: { try iniStore.ensureSeeded(version: $0) },
            makeInstaller: { request in
                let php = paths.phpBinary(version: request.phpVersion)
                let phpIni = paths.phpIni(version: request.phpVersion)
                switch request.kind {
                case .wordpress:
                    let phar = try await PharProvisioner.wpCli(paths: paths).provision()
                    return WordPressInstaller(php: php, phpIni: phpIni, wpCliPhar: phar)
                case .laravel:
                    let phar = try await ComposerProvisioner(paths: paths).provision()
                    return LaravelInstaller(php: php, phpIni: phpIni, composerPhar: phar)
                case .empty:
                    return EmptySiteInstaller()
                }
            },
            enableHTTPSForSite: { site in
                try await Task.detached { try httpsProvisioner.enableHTTPS(for: site) }.value
            },
            performRestore: { site, request, emit in
                let service = WordPressRestoreService(
                    paths: paths,
                    ensureEngine: ensureEngine,
                    applyServerConfig: { await MainActor.run { server.reconcileAfterRuntimeChange() } },
                    enableHTTPS: {
                        try await Task.detached { try httpsProvisioner.enableHTTPS(for: site) }.value
                        await MainActor.run { registry.setSecure(site, true) }
                    },
                    finalizeSite: { database in
                        await MainActor.run {
                            registry.setDatabaseName(site, database)
                            registry.setPHPVersion(site, to: request.phpVersion)
                            registry.reinspect(site)
                        }
                    }
                )
                return try await service.restore(request, emit: emit)
            }
        )
    }

    // MARK: SiteProvisioning

    @MainActor
    public func install(_ request: NewSiteRequest, enableHTTPS: Bool,
                        emit: @escaping @Sendable (InstallEvent) -> Void) async throws -> SiteSummary {
        try registry.validateDomain(request.domain)
        try ensureSeededIni(request.phpVersion)
        let installer = try await makeInstaller(request)
        let registry = registry
        let site = try await installService.install(request, installer: installer, register: { folder in
            try await MainActor.run {
                try registry.add(folder: folder, phpVersion: request.phpVersion, databaseName: request.databaseName)
            }
        }, emit: emit)
        if enableHTTPS {
            emit(InstallEvent(phase: .finalizing, message: "Enabling HTTPS…"))
            try await enableHTTPSForSite(site)
            registry.setSecure(site, true)
        }
        return SiteSummary(site)
    }

    @MainActor
    public func importFolder(_ folder: URL, domain: String, phpVersion: String,
                             createDatabase: Bool, enableHTTPS: Bool) async throws -> SiteSummary {
        let safe = try resolveSafeDocroot(folder)
        if registry.sites.contains(where: {
            URL(fileURLWithPath: $0.path).resolvingSymlinksInPath().standardizedFileURL.path == safe.path
        }) {
            throw SiteImportError.alreadyRegistered(safe.lastPathComponent)
        }
        try registry.validateDomain(domain)
        try ensureSeededIni(phpVersion)

        let databaseName = createDatabase ? DomainSlug.make(safe.lastPathComponent) : nil
        if let databaseName {
            if try await databaseExists(databaseName) {
                throw SiteImportError.databaseExists(databaseName)
            }
            try await self.createDatabase(databaseName)
        }
        let registered = try registry.add(
            folder: safe,
            phpVersion: phpVersion,
            respectProjectMarkers: false,
            databaseName: databaseName
        )
        if registered.domain != domain {
            try registry.editDomain(registered, to: domain)
        }
        let site = registry.sites.first(where: { $0.id == registered.id }) ?? registered
        if enableHTTPS {
            try await enableHTTPSForSite(site)
            registry.setSecure(site, true)
        }
        return SiteSummary(site)
    }

    @MainActor
    public func registerFolder(_ folder: URL, phpVersion: String) throws -> SiteSummary {
        SiteSummary(try registry.add(folder: folder, phpVersion: phpVersion))
    }

    @MainActor
    public func addProxySite(name: String, domain: String, target: String,
                             enableHTTPS: Bool) async throws -> SiteSummary {
        let upstream: ProxyTarget
        switch ProxyTarget.parse(target) {
        case let .success(value): upstream = value
        case let .failure(error): throw error
        }
        let site = try registry.addProxy(name: name, domain: domain, target: upstream)
        // Fail-closed: HTTPS lỗi thì site vẫn tồn tại ở HTTP (giống import, không rollback record).
        if enableHTTPS {
            try await enableHTTPSForSite(site)
            registry.setSecure(site, true)
        }
        return SiteSummary(registry.sites.first(where: { $0.id == site.id }) ?? site)
    }

    @MainActor
    public func remove(_ id: UUID, deleteFolder: Bool, dropDatabase: Bool) async throws {
        guard let site = registry.sites.first(where: { $0.id == id }) else { return }
        let registry = registry
        let dropDB = self.dropDatabase
        // Proxy site không có thư mục: không bao giờ đụng filesystem khi remove.
        let deleteFolder = deleteFolder && site.hasFolder
        let coordinator = SiteRemovalCoordinator(
            deleteFolder: { site in
                guard deleteFolder else { return }
                try await MainActor.run { try registry.deleteFolderForRemoval(site) }
            },
            dropDatabase: { name in
                guard dropDatabase else { return }
                try await dropDB(name)
            },
            removeRecord: { site in await MainActor.run { registry.remove(site) } }
        )
        try await coordinator.remove(site)
    }

    public nonisolated func scan(root: URL, tld: String, existingPaths: [String]) -> [ScannedFolder] {
        scanner.scan(root: root, tld: tld, existingPaths: existingPaths).map {
            ScannedFolder(
                folder: $0.folder,
                docroot: $0.docroot,
                proposedDomain: $0.proposedDomain,
                kind: SiteKind(rawValue: $0.type.rawValue) ?? .php,
                alreadyRegistered: $0.alreadyRegistered
            )
        }
    }

    public nonisolated func inspect(folder: URL, tld: String) -> FolderInspection {
        let r = inspector.inspect(folder: folder, tld: tld)
        return FolderInspection(
            docroot: r.docroot,
            defaultDomain: r.defaultDomain,
            kind: SiteKind(rawValue: r.type.rawValue) ?? .php
        )
    }

    // MARK: WordPressRestoring

    public nonisolated func inspectBackup(_ file: URL) throws -> WordPressBackupKind {
        try WordPressBackupInspector().inspect(file)
    }

    @MainActor
    public func restore(_ request: RestoreRequest, into siteID: UUID,
                        emit: @escaping @Sendable (RestoreEvent) -> Void) async throws -> RestoreOutcome {
        guard let site = registry.sites.first(where: { $0.id == siteID }) else {
            throw RestoreServiceError.sourceURLUnresolved
        }
        return try await performRestore(site, request, emit)
    }

    // MARK: SiteIDEConfiguring

    public nonisolated func writeVSCodeDebugConfig(projectRoot: URL, docroot: URL) throws -> URL {
        try ideWriter.writeVSCode(projectRoot: projectRoot, docroot: docroot)
    }
}
