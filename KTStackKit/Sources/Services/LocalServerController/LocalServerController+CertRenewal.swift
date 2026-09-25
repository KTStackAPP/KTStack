import Foundation
import KTStackCore

extension LocalServerController {
    func renameSecureSite(_ site: Site, to rawDomain: String) throws {
        let domain = rawDomain.trimmingCharacters(in: .whitespaces).lowercased()
        try registry.validateDomain(domain, excluding: site.id)
        guard !isBusy else { throw SiteRegistry.RegistryError.serverBusy }
        isBusy = true; lastError = nil
        var renamed = site
        renamed.domain = domain
        let provisioner = httpsProvisioner
        Task.detached(priority: .userInitiated) {
            var failure: String?
            do { try provisioner.enableHTTPS(for: renamed) } catch { failure = error.localizedDescription }
            await MainActor.run {
                self.isBusy = false
                if let failure { self.lastError = failure } else { try? self.registry.editDomain(site, to: domain) }
            }
        }
    }

    public func renewCertificatesAfterCAChange() {
        didCheckCertRenewal = false
        renewCertificatesIfNeeded()
    }

    func renewCertificatesIfNeeded() {
        guard !didCheckCertRenewal, registry.loadFailure == nil else { return }
        didCheckCertRenewal = true
        guard FileManager.default.fileExists(atPath: paths.caRootCert.path) else { return }
        let secure = registry.sites.filter(\.secure)
        guard !secure.isEmpty else { return }
        let policy = CertRenewalPolicy(paths: paths, minter: certMinter)
        let provisioner = httpsProvisioner
        Task.detached(priority: .utility) {
            var renewed = false
            for site in secure where policy.needsRenewal(site.domain) {
                do {
                    try provisioner.enableHTTPS(for: site)
                    renewed = true
                } catch {
                    NSLog("KTStack: certificate renewal failed for \(site.domain): \(error.localizedDescription)")
                }
            }
            if renewed { await MainActor.run { self.onRegistryChanged() } }
        }
    }
}
