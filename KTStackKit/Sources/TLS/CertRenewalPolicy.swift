import Foundation
import KTStackCore
import Security

struct CertRenewalPolicy {
    let paths: AppSupportPaths
    let minter: CertMinter

    func needsRenewal(_ name: String) -> Bool {
        if minter.needsRenewal(name: name) { return true }
        guard let leaf = Self.certificate(at: paths.siteCert(name)),
              let ca = Self.certificate(at: paths.caRootCert) else { return false }
        return !Self.isIssued(leaf, by: ca)
    }

    static func isIssued(_ leaf: SecCertificate, by ca: SecCertificate) -> Bool {
        guard let issuer = SecCertificateCopyNormalizedIssuerSequence(leaf) as Data?,
              let subject = SecCertificateCopyNormalizedSubjectSequence(ca) as Data? else { return true }
        return issuer == subject
    }

    static func certificate(at url: URL) -> SecCertificate? {
        guard let pem = try? Data(contentsOf: url), let der = CertMinter.pemToDER(pem) else { return nil }
        return SecCertificateCreateWithData(nil, der as CFData)
    }
}
