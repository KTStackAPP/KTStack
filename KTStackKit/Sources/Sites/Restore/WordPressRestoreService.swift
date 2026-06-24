import Foundation

public final class WordPressRestoreService: Sendable {
    private let paths: AppSupportPaths
    private let dumpService: DumpService
    private let provisioner: DatabaseProvisioner
    private let staging: RestoreStagingArea
    private let register: @Sendable (URL) async throws -> Site
    private let unregister: @Sendable (Site) async -> Void
    private let applyServerConfig: @Sendable () async throws -> Void
    private let enableHTTPS: @Sendable (Site) async throws -> Void

    public init(paths: AppSupportPaths,
                dumpService: DumpService = DumpService(),
                ensureEngine: @escaping @Sendable () async throws -> Void,
                register: @escaping @Sendable (URL) async throws -> Site,
                unregister: @escaping @Sendable (Site) async -> Void,
                applyServerConfig: @escaping @Sendable () async throws -> Void,
                enableHTTPS: @escaping @Sendable (Site) async throws -> Void) {
        self.paths = paths
        self.dumpService = dumpService
        self.provisioner = DatabaseProvisioner(ensureEngine: ensureEngine)
        self.staging = RestoreStagingArea(paths: paths)
        self.register = register
        self.unregister = unregister
        self.applyServerConfig = applyServerConfig
        self.enableHTTPS = enableHTTPS
    }

    public func restore(_ request: RestoreRequest,
                        emit: @Sendable @escaping (RestoreEvent) -> Void) async throws -> RestoreOutcome {
        let stagingRoot = try staging.make()
        defer { staging.discard(stagingRoot) }

        var undo: [@Sendable () async -> Void] = []
        func rollback() async { for step in undo.reversed() { await step() } }

        do {
            let php = paths.phpBinary(version: request.phpVersion)
            let iniURL = paths.phpIni(version: request.phpVersion)
            let phpIni = FileManager.default.fileExists(atPath: iniURL.path) ? iniURL : nil
            let wpCliPhar = paths.wpCliPhar
            var warnings: [String] = []

            emit(RestoreEvent(phase: .detecting, message: "Inspecting backup…"))
            let kind = try WordPressBackupInspector().inspect(request.backupFile)
            let extractor: RestoreArchiveExtractor = kind == .aioWpress
                ? WPressArchiveReader() : DuplicatorArchiveReader()

            emit(RestoreEvent(phase: .extracting, message: "Extracting \(kind.label) backup…"))
            let payload = try await extractor.extract(request.backupFile, into: stagingRoot) {
                emit(RestoreEvent(phase: .extracting, message: $0))
            }

            try await preflight(request: request, wpCliPhar: wpCliPhar)

            let baseLabel = RestoreNaming.label(from: request.siteName)
            let label = try await RestoreNaming.uniqueName(base: baseLabel, separator: "-") { candidate in
                FileManager.default.fileExists(atPath: paths.sites.appendingPathComponent(candidate).path)
            }
            let targetDocroot = paths.sites.appendingPathComponent(label, isDirectory: true)

            try Task.checkCancellation()
            emit(RestoreEvent(phase: .reconcilingCore, message: "Preparing WordPress files…"))
            let reconciler = WordPressCoreReconciler(php: php, phpIni: phpIni, wpCliPhar: wpCliPhar)
            let reconcileResult = try await reconciler.reconcile(payload: payload, targetDocroot: targetDocroot) {
                emit(RestoreEvent(phase: .reconcilingCore, message: $0))
            }
            undo.append { try? FileManager.default.removeItem(at: targetDocroot) }
            WordPressPayloadMetadata.stripInstallerScaffolding(docroot: targetDocroot)
            if reconcileResult.usedLatestFallback, let requested = reconcileResult.requestedVersion {
                warnings.append("WordPress \(requested) was unavailable; the latest stable release was installed instead.")
            }

            try Task.checkCancellation()
            let databaseBase = RestoreNaming.databaseBase(from: label)
            let database = try await RestoreNaming.uniqueName(base: databaseBase) {
                try await provisioner.exists($0)
            }
            emit(RestoreEvent(phase: .creatingDatabase, message: "Creating database \(database)…"))
            try await provisioner.createDatabase(database)
            undo.append { try? await self.provisioner.dropDatabase(database) }

            try Task.checkCancellation()
            emit(RestoreEvent(phase: .importingDatabase, message: "Importing database…"))
            try await dumpService.importDump(profile: .managedMySQL, password: nil,
                                             database: database, from: payload.sqlDump)

            try Task.checkCancellation()
            emit(RestoreEvent(phase: .writingConfig, message: "Writing wp-config.php…"))
            try WPConfigWriter(php: php, phpIni: phpIni, wpCliPhar: wpCliPhar)
                .write(into: targetDocroot, database: database, tablePrefix: payload.tablePrefix) {
                    emit(RestoreEvent(phase: .writingConfig, message: $0))
                }

            try Task.checkCancellation()
            emit(RestoreEvent(phase: .registeringSite, message: "Registering site…"))
            let site = try await register(targetDocroot)
            undo.append { await self.unregister(site); try? await self.applyServerConfig() }

            try Task.checkCancellation()
            let searchReplace = WordPressSearchReplaceRunner(php: php, phpIni: phpIni, wpCliPhar: wpCliPhar)
            let newURL = "https://\(site.domain)"
            guard let oldURL = payload.sourceURL ?? searchReplace.currentSiteURL(docroot: targetDocroot) else {
                throw RestoreServiceError.sourceURLUnresolved
            }
            emit(RestoreEvent(phase: .searchReplace, message: "Rewriting site address…"))
            try await searchReplace.run(docroot: targetDocroot, oldURL: oldURL, newURL: newURL) {
                emit(RestoreEvent(phase: .searchReplace, message: $0))
            }

            try Task.checkCancellation()
            emit(RestoreEvent(phase: .configuringServer, message: "Configuring web server…"))
            try await applyServerConfig()
            if request.secure {
                try await enableHTTPS(site)
                try await applyServerConfig()
            }

            warnings.append("Hardcoded URLs inside PHP files are not rewritten automatically.")
            emit(RestoreEvent(phase: .done, message: "Site ready at \(newURL)"))
            return RestoreOutcome(site: site, warnings: warnings)
        } catch {
            await rollback()
            throw error
        }
    }

    private func preflight(request: RestoreRequest, wpCliPhar: URL) async throws {
        let installed = BundledPHP.availableVersions(php: paths.phpRuntimesRoot)
        guard installed.contains(request.phpVersion) else {
            throw RestoreServiceError.phpVersionNotInstalled(request.phpVersion)
        }
        _ = try await PharProvisioner.wpCli(paths: paths).provision()
    }
}
