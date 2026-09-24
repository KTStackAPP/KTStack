import Foundation
import KTDatabasePlugin
import KTStackCore
import KTStackKit

extension AppDelegate {
    @MainActor
    func makeIPCDispatcher() -> KTIPCCommandDispatcher {
        let backups = ManagedDatabaseBackupService(tools: DatabaseToolsService(paths: AppSupportPaths()))
        return KTIPCCommandDispatcher(
            serverProvider: { [weak self] in await MainActor.run { self?.server } },
            servicesProvider: { [weak self] in await MainActor.run { self?.services } },
            backupProvider: { backups }
        )
    }
}
