import KTStackCore
import KTStackKit

extension AppDelegate {
    @MainActor
    func makeSiteProvisioning() -> SiteProvisioningService {
        let services = services
        return SiteProvisioningService(
            paths: AppSupportPaths(),
            server: server,
            ensureSQL: { try await services.ensureSQLFamilyRunning() }
        )
    }
}
