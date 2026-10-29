import Foundation
import Security

public enum CustomCertificateError: LocalizedError, Equatable {
    case notPEMCertificate
    case notPEMKey
    case encryptedKey
    case expired(Date)
    case namesNotCovered([String])
    case needsCustomCertificate(String)
    case rejected(String)
    case couldNotValidate
    case reloadFailedReverted(String)

    public var errorDescription: String? {
        switch self {
        case .notPEMCertificate:
            "The certificate file is not a PEM certificate."
        case .notPEMKey:
            "The key file is not a PEM private key."
        case .encryptedKey:
            "The private key is encrypted. Export it without a passphrase and import again."
        case let .expired(date):
            "The certificate expired on \(date.formatted(date: .abbreviated, time: .omitted))."
        case let .namesNotCovered(names):
            "The certificate does not cover: \(names.joined(separator: ", ")). Import a certificate that includes them."
        case let .needsCustomCertificate(domain):
            "\(domain) needs an imported certificate to serve HTTPS."
        case let .rejected(stderr):
            "nginx rejected the certificate: \(stderr)"
        case .couldNotValidate:
            "Could not run nginx to check the certificate. Nothing was changed."
        case let .reloadFailedReverted(message):
            "nginx failed to reload with the new certificate, so the previous one was restored: \(message)"
        }
    }
}

// Đọc cặp PEM: tên SAN + hạn; từ chối thứ nginx không load được hoặc không nên load.
public struct CustomCertificateInspector {
    public init() {}

    public func inspect(certPEM: Data, keyPEM: Data, now: Date = Date()) throws -> (notAfter: Date, names: [String]) {
        let keyText = String(decoding: keyPEM, as: UTF8.self)
        if keyText.contains("ENCRYPTED PRIVATE KEY") || keyText.contains("Proc-Type: 4,ENCRYPTED") {
            throw CustomCertificateError.encryptedKey
        }
        guard keyText.contains("-----BEGIN"), keyText.contains("PRIVATE KEY-----") else {
            throw CustomCertificateError.notPEMKey
        }
        guard let der = CertMinter.pemToDER(certPEM),
              let cert = SecCertificateCreateWithData(nil, der as CFData),
              let notAfter = CertMinter.notAfter(pem: certPEM)
        else { throw CustomCertificateError.notPEMCertificate }
        if notAfter <= now { throw CustomCertificateError.expired(notAfter) }
        return (notAfter, Self.dnsNames(cert))
    }

    // Tên server được cover khi trùng hẳn, hoặc cert có `*.<rest>` và tên là đúng một label + `.<rest>`.
    public static func uncovered(_ serverNames: [String], by certNames: [String]) -> [String] {
        let names = Set(certNames.map { $0.lowercased() })
        return serverNames.filter { name in
            let name = name.lowercased()
            if names.contains(name) { return false }
            if name.hasPrefix("*.") { return true }
            guard let dot = name.firstIndex(of: ".") else { return true }
            return !names.contains("*" + name[dot...])
        }
    }

    private static func dnsNames(_ cert: SecCertificate) -> [String] {
        let keys = [kSecOIDSubjectAltName] as CFArray
        guard let values = SecCertificateCopyValues(cert, keys, nil) as? [CFString: Any],
              let san = values[kSecOIDSubjectAltName] as? [CFString: Any],
              let entries = san[kSecPropertyKeyValue] as? [[CFString: Any]]
        else { return [] }
        return entries.compactMap { entry in
            guard entry[kSecPropertyKeyLabel] as? String == "DNS Name" else { return nil }
            return (entry[kSecPropertyKeyValue] as? String)?.lowercased()
        }
    }
}
