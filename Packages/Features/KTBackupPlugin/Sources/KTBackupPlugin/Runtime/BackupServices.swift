import Foundation
import KTPlatformContracts

public struct BackupServices: Sendable {
    public let paths: BackupPaths
    public let store: BackupStore
    public let secrets: any BackupSecretStoring
    public let factory: BackupDestinationFactory
    public let coordinator: BackupCoordinator
    public let databases: any ScheduledDatabaseBackupProviding
    public let picker: GooglePickerConfiguration?

    public init(paths: BackupPaths, secrets: any BackupSecretStoring, transport: any HTTPTransport,
                databases: any ScheduledDatabaseBackupProviding, environment: any BackupRuntimeEnvironment,
                defaultsDomain: String?, bundleInfo: [String: Any]?) {
        self.paths = paths
        self.secrets = secrets
        self.databases = databases
        store = BackupStore(paths: paths)
        factory = BackupDestinationFactory(paths: paths, secrets: secrets, transport: transport,
                                           bundledGoogleClient: GoogleOAuthClient.bundled(bundleInfo))
        picker = GooglePickerConfiguration.bundled(bundleInfo)
        let settings = SettingsSnapshotWriter(appSupportRoot: paths.appSupportRoot, defaultsDomain: defaultsDomain)
        let runner = BackupPlanRunner(databases: databases, environment: environment, paths: paths, settings: settings)
        coordinator = BackupCoordinator(store: store, runner: runner, destinations: factory, logger: BackupLogger(fileURL: paths.logFile))
    }

    public func restorer(outputParent: URL) -> BackupRestorer {
        BackupRestorer(databases: databases, paths: paths, outputParent: outputParent)
    }
}
