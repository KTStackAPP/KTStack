import Foundation
import KTPlatformContracts
import KTStackCore

// Gom orchestration PHP config đang nằm trong view/model App: install extension → restart pool →
// invalidate; save ini → validate → write(.bak) → reload → rollback khi fail. Plugin chỉ giữ UI state.
// Fail-closed extension invariant vẫn ở PHPExtensionInstaller; service không viết directive.
public struct PHPConfigService: PHPExtensionManaging, PHPIniEditing, PHPPoolEditing, Sendable {
    private let paths: AppSupportPaths
    private let reloadPool: @Sendable (String) async throws -> Void
    private let restartPool: @Sendable (String) async throws -> Void
    private let checkPool: @Sendable (String) async -> PHPFPMConfigCheck.Result

    public init(
        paths: AppSupportPaths,
        reloadPool: @escaping @Sendable (String) async throws -> Void,
        restartPool: @escaping @Sendable (String) async throws -> Void,
        checkPool: (@Sendable (String) async -> PHPFPMConfigCheck.Result)? = nil
    ) {
        self.paths = paths
        self.reloadPool = reloadPool
        self.restartPool = restartPool
        self.checkPool = checkPool ?? { version in
            await Task.detached(priority: .userInitiated) {
                PHPFPMConfigCheck(paths: paths).run(version: version)
            }.value
        }
    }

    public func extensions(phpVersion: String) async -> [PHPExtensionEntry] {
        let catalog = PHPExtensionCatalog(paths: paths)
        let version = phpVersion
        let probe = await Task.detached(priority: .utility) {
            ExtensionProbe(
                installed: catalog.installedExtensions(version),
                compiledIn: catalog.compiledInModules(version),
                onDisk: Dictionary(uniqueKeysWithValues: PHPExtensionCatalog.descriptors
                    .filter { !$0.isBuiltIn }
                    .map { ($0.id, catalog.sharedObjectExists($0.id, phpVersion: version)) })
            )
        }.value

        return PHPExtensionCatalog.descriptors
            .filter { $0.id != "xdebug" }
            .map { ext in
                let status = catalog.status(
                    ext, phpVersion: version,
                    installed: probe.installed, soOnDisk: probe.onDisk[ext.id] ?? false,
                    compiledIn: probe.compiledIn
                )
                let effectiveBuiltIn = ext.isBuiltIn || probe.compiledIn.contains(ext.id)
                return PHPExtensionEntry(ext: Self.info(ext, isBuiltIn: effectiveBuiltIn), state: Self.state(status))
            }
            .sorted { lhs, rhs in
                if lhs.ext.isBuiltIn != rhs.ext.isBuiltIn { return !lhs.ext.isBuiltIn } // optional first
                return lhs.ext.displayName.localizedCaseInsensitiveCompare(rhs.ext.displayName) == .orderedAscending
            }
    }

    public func installExtension(
        _ id: String,
        phpVersion: String,
        onProgress: @escaping @Sendable (Double) -> Void
    ) async throws -> PHPExtensionInstallOutcome {
        let version = phpVersion
        if PHPExtensionCatalog(paths: paths).compiledInModules(version).contains(id) {
            throw PHPExtensionInstaller.InstallError.alreadyBuiltIn(ext: id, phpVersion: version)
        }
        let installer = PHPExtensionInstaller(paths: paths)
        let result = try await installer.install(id, phpVersion: phpVersion) { progress in
            onProgress(progress.fraction)
        }
        try await restartPool(phpVersion)
        PHPModules.invalidate(version: phpVersion)
        if case let .installedButFailedToLoad(warning) = result {
            return PHPExtensionInstallOutcome(loaded: false, warning: warning)
        }
        return PHPExtensionInstallOutcome(loaded: true, warning: nil)
    }

    public func uninstallExtension(_ id: String, phpVersion: String) async throws {
        let installer = PHPExtensionInstaller(paths: paths)
        try installer.uninstall(id, phpVersion: phpVersion)
        try await restartPool(phpVersion) // RESTART, not reload — unloads the live .so
        PHPModules.invalidate(version: phpVersion)
    }

    public var xdebugClientPort: Int { XdebugController.clientPort }

    public func isXdebugSupported(phpVersion: String) -> Bool {
        makeXdebug().isSupported(version: phpVersion)
    }

    public func isXdebugEnabled(phpVersion: String) -> Bool {
        makeXdebug().isEnabled(version: phpVersion)
    }

    public func setXdebug(_ enabled: Bool, phpVersion: String) async throws {
        let controller = makeXdebug()
        if enabled {
            try await controller.enable(version: phpVersion)
        } else {
            try await controller.disable(version: phpVersion)
        }
    }

    public var defaultTemplate: String { PHPIniTemplate.default }

    public func readIni(phpVersion: String) throws -> String {
        try PHPIniStore(paths: paths).read(version: phpVersion)
    }

    public func saveIni(phpVersion: String, contents: String) async throws {
        let store = PHPIniStore(paths: paths)
        let version = phpVersion
        if let problem = await Task.detached(priority: .userInitiated, operation: {
            store.validate(version: version, contents: contents)
        }).value {
            throw PHPIniSaveError.syntax(problem)
        }
        try store.write(version: version, contents: contents) // atomic + .bak
        do {
            try await reloadPool(version)
        } catch {
            _ = try? store.restoreBackup(version: version)
            try? await reloadPool(version)
            throw PHPIniSaveError.reloadFailedReverted(error.localizedDescription)
        }
    }

    public var defaultPoolSettings: PHPPoolSettings { .default }

    public func poolSettings(phpVersion: String) throws -> PHPPoolSettings {
        try PHPPoolSettingsStore(paths: paths).load(version: phpVersion)
    }

    // Fail-closed: validate → ghi(.bak) + render → php-fpm -t → restart → rollback nếu bất kỳ bước hỏng.
    public func savePoolSettings(phpVersion: String, _ settings: PHPPoolSettings) async throws {
        if let problem = settings.validate() { throw PHPPoolSaveError.invalid(problem) }
        let store = PHPPoolSettingsStore(paths: paths)
        let writer = PHPFPMPoolWriter()
        let previous = try store.load(version: phpVersion)

        try store.write(version: phpVersion, settings: settings)
        try writer.write(paths: paths, poolName: phpVersion)

        if case let .invalid(err) = await checkPool(phpVersion) {
            try? store.write(version: phpVersion, settings: previous)
            try? writer.write(paths: paths, poolName: phpVersion)
            throw PHPPoolSaveError.rejected(err)
        }

        do {
            try await restartPool(phpVersion)
        } catch {
            try? store.write(version: phpVersion, settings: previous)
            try? writer.write(paths: paths, poolName: phpVersion)
            try? await restartPool(phpVersion)
            throw PHPPoolSaveError.restartFailedReverted(error.localizedDescription)
        }
    }

    private func makeXdebug() -> XdebugController {
        XdebugController(paths: paths, reloadPool: restartPool)
    }

    private struct ExtensionProbe: Sendable {
        let installed: Set<String>
        let compiledIn: Set<String>
        let onDisk: [String: Bool]
    }

    private static func info(_ ext: PHPExtension, isBuiltIn: Bool) -> PHPExtensionInfo {
        PHPExtensionInfo(
            id: ext.id,
            displayName: ext.displayName,
            kind: ext.type.rawValue,
            summary: ext.summary,
            isBuiltIn: isBuiltIn
        )
    }

    private static func state(_ status: PHPExtensionStatus) -> PHPExtensionState {
        switch status {
        case .builtIn: .builtIn
        case .installed: .installed
        case .installedButFailedToLoad: .installedButFailedToLoad
        case .available: .available
        case .unavailable: .unavailable
        }
    }
}
