import Foundation
import Security

/// Mints + tracks per-site TLS leaves via `MkcertRunner`. Each secured site gets a leaf at
/// `config/certs/<name>/{cert,key}.pem` with SAN = its domain. Tracks `notAfter` so the orchestrator
/// can re-mint before expiry (mkcert leaves are long-lived but finite).
public struct CertMinter {
    private let paths: AppSupportPaths
    private let runner: MkcertRunner

    public init(paths: AppSupportPaths, runner: MkcertRunner) {
        self.paths = paths
        self.runner = runner
    }

    public func certExists(name: String) -> Bool {
        let fm = FileManager.default
        return fm.fileExists(atPath: paths.siteCert(name).path)
            && fm.fileExists(atPath: paths.siteKey(name).path)
    }

    public enum CertError: LocalizedError {
        case nonLocalDomain(String, tld: String)
        public var errorDescription: String? {
            switch self {
            case .nonLocalDomain(let d, let t): return "Refusing to mint a certificate for “\(d)” — only .\(t) domains are allowed."
            }
        }
    }

    /// Mint (or re-mint) the leaf for `name` → `domain`. Returns the cert + key paths.
    /// Guards that `domain` is scoped to the configured dev `tld` — the local CA must NEVER mint a
    /// publicly-named leaf. The caller passes the live TLD (`AppPreferences.tld`) so a custom TLD's
    /// sites can still be secured.
    @discardableResult
    public func mint(name: String, domain: String, tld: String = AppPreferences.defaultTLD) throws -> (cert: URL, key: URL) {
        guard domain.hasSuffix(".\(tld)") else { throw CertError.nonLocalDomain(domain, tld: tld) }
        let cert = paths.siteCert(name), key = paths.siteKey(name)
        try runner.mint(domain: domain, certFile: cert, keyFile: key)
        return (cert, key)
    }

    /// Remove a site's cert dir (e.g. on remove / rename).
    public func removeCert(name: String) {
        try? FileManager.default.removeItem(at: paths.siteCertDir(name))
    }

    /// Delete cert dirs not in `keeping` (the current set of registered site domains), so a
    /// removed/renamed site doesn't leave key material behind.
    public func pruneOrphans(keeping: Set<String>) {
        let fm = FileManager.default
        guard let dirs = try? fm.contentsOfDirectory(at: paths.certsDir,
                                                     includingPropertiesForKeys: nil) else { return }
        for dir in dirs where !keeping.contains(dir.lastPathComponent) {
            try? fm.removeItem(at: dir)
        }
    }

    /// The leaf's expiry, read from the PEM via Security framework (no openssl dependency).
    public func notAfter(name: String) -> Date? {
        guard let pem = try? Data(contentsOf: paths.siteCert(name)) else { return nil }
        return Self.notAfter(pem: pem)
    }

    /// True when the leaf is missing or expires within `within` (default 30 days) → re-mint.
    public func needsRenewal(name: String, within: TimeInterval = 30 * 24 * 3600) -> Bool {
        guard let exp = notAfter(name: name) else { return true }
        return exp.timeIntervalSinceNow < within
    }

    // MARK: - PEM expiry parsing

    static func notAfter(pem: Data) -> Date? {
        guard let der = pemToDER(pem),
              let cert = SecCertificateCreateWithData(nil, der as CFData) else { return nil }
        let keys = [kSecOIDX509V1ValidityNotAfter] as CFArray
        guard let values = SecCertificateCopyValues(cert, keys, nil) as? [CFString: Any],
              let entry = values[kSecOIDX509V1ValidityNotAfter] as? [CFString: Any],
              let seconds = entry[kSecPropertyKeyValue] as? Double else { return nil }
        // SecCertificate reports validity as CFAbsoluteTime (seconds since 2001-01-01).
        return Date(timeIntervalSinceReferenceDate: seconds)
    }

    /// Extract the DER bytes from the first PEM CERTIFICATE block.
    static func pemToDER(_ pem: Data) -> Data? {
        guard let text = String(data: pem, encoding: .utf8) else { return nil }
        let lines = text.split(separator: "\n")
        var base64 = "", inside = false
        for line in lines {
            if line.contains("BEGIN CERTIFICATE") { inside = true; continue }
            if line.contains("END CERTIFICATE") { break }
            if inside { base64 += line }
        }
        return Data(base64Encoded: base64)
    }
}
