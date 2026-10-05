import Foundation
import KTPlatformContracts
import KTPluginKit
import KTStackCore
import SwiftUI

public final class KTBackupPlugin: PluginLifecycle, SettingsProviding, TerminationVetoing {
    let services: BackupServices
    private let environment: PlatformBackupEnvironment

    @MainActor public lazy var scheduler = BackupScheduler(coordinator: services.coordinator, store: services.store)
    @MainActor lazy var destinations = BackupDestinationsModel(services: services, scheduler: scheduler)

    public init(
        databases: any ScheduledDatabaseBackupProviding,
        engines: any DatabaseEngineManaging,
        siteCatalog: any SiteCatalogManaging,
        appSupport: AppSupportPaths = AppSupportPaths(),
        bundleInfo: [String: Any]? = Bundle.main.infoDictionary,
        defaultsDomain: String? = Bundle.main.bundleIdentifier
    ) {
        environment = PlatformBackupEnvironment(engines: engines, siteCatalog: siteCatalog)
        services = BackupServices(
            paths: BackupPaths(appSupportRoot: appSupport.root),
            secrets: KeychainBackupSecretStore(),
            transport: URLSessionHTTPTransport(),
            databases: databases,
            environment: environment,
            defaultsDomain: defaultsDomain,
            bundleInfo: bundleInfo
        )
    }

    public func start() async {
        try? services.paths.ensureDirectories()
        await MainActor.run { scheduler.start() }
    }

    public func shutdown() async {}

    @MainActor
    public func stopScheduling() {
        scheduler.stop()
    }

    @MainActor
    public func makeSettingsPane() -> AnyView {
        AnyView(BackupSettingsPane(scheduler: scheduler, destinations: destinations, environment: environment, services: services))
    }

    @MainActor
    public func pendingWorkDescription() -> String? {
        let names = scheduler.activePlanNames
        guard !names.isEmpty else { return nil }
        return "A scheduled backup is still running (\(names.joined(separator: ", "))). Quitting now discards it."
    }
}
