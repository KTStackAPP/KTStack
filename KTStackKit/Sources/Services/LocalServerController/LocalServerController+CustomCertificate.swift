import Foundation
import KTStackCore

public extension LocalServerController {
    // Không đi qua reconcile() vì cần kết quả nginx -t trước khi persist, giống saveFrontDirectives.
    func importCustomCertificate(_ site: Site, certPath: String, keyPath: String) async throws {
        guard !isBusy else { throw SiteRegistry.RegistryError.serverBusy }
        let importer = certificateImporter()
        isBusy = true
        defer { finishDirectivesSave() }
        try await importer.importCertificate(site, certPath: certPath, keyPath: keyPath)
    }

    func removeCustomCertificate(_ site: Site) async throws {
        guard !isBusy else { throw SiteRegistry.RegistryError.serverBusy }
        let importer = certificateImporter()
        isBusy = true
        defer { finishDirectivesSave() }
        try await importer.removeCertificate(site)
    }

    private func certificateImporter() -> SiteCertificateImporter {
        let generator = self.generator
        let port = httpPort
        return SiteCertificateImporter(
            store: CustomCertificateStore(paths: paths),
            generate: { sites in
                try await Task.detached(priority: .userInitiated) {
                    _ = try generator.generate(sites: sites, port: port)
                }.value
            },
            validate: { await self.validateNginxConfig() },
            reload: { try await self.reloadNginxConfig() },
            liveSites: { self.registry.sites },
            persist: { self.registry.setCustomCertificate($0, $1, secure: $2) }
        )
    }
}
