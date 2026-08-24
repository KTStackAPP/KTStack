import Foundation
import KTPlatformContracts
import KTStackCore

// Gom orchestration PHP config đang nằm trong view/model App: install extension → restart pool →
// invalidate; save ini → validate → write(.bak) → reload → rollback khi fail. Plugin chỉ giữ UI state.
// Fail-closed extension invariant vẫn ở PHPExtensionInstaller; service không viết directive.
public struct PHPConfigService: PHPExtensionManaging, PHPIniEditing, Sendable {
    private let paths: AppSupportPaths
    private let reloadPool: @Sendable (String) async throws -> Void
    private let restartPool: @Sendable (String) async throws -> Void

    public init(
        paths: AppSupportPaths,
        reloadPool: @escaping @Sendable (String) async throws -> Void,
        restartPool: @escaping @Sendable (String) async throws -> Void
    ) {
        self.paths = paths
        self.reloadPool = reloadPool
        self.restartPool = restartPool
    }

    public func extensions(phpVersion: String) async -> [PHPExtensionEntry] {
        let catalog = PHPExtensionCatalog(paths: paths)
        let version = phpVersion
        let (installed, onDisk): (Set<String>, [String: Bool]) = await Task.detached(priority: .utility) {
            let installed = catalog.installedExtensions(version)
            var onDisk: [String: Bool] = [:]
            for ext in PHPExtensionCatalog.descriptors where !ext.isBuiltIn {
                onDisk[ext.id] = catalog.sharedObjectExists(ext.id, phpVersion: version)
            }
            return (installed, onDisk)
        }.value

        return PHPExtensionCatalog.descriptors
            .filter { $0.id != "xdebug" }
            .map { ext in
                let status = catalog.status(
                    ext, phpVersion: version, installed: installed, soOnDisk: onDisk[ext.id] ?? false
                )
                return PHPExtensionEntry(ext: Self.info(ext), state: Self.state(status))
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

    private func makeXdebug() -> XdebugController {
        XdebugController(paths: paths, reloadPool: restartPool)
    }

    private static func info(_ ext: PHPExtension) -> PHPExtensionInfo {
        PHPExtensionInfo(
            id: ext.id,
            displayName: ext.displayName,
            kind: ext.type.rawValue,
            summary: ext.summary,
            isBuiltIn: ext.isBuiltIn
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
