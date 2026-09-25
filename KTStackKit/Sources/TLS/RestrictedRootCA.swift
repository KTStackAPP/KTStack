import CryptoKit
import Foundation
import KTStackCore

public enum RestrictedRootCA {
    public static let policyKey = "KTStack.restrictLocalCA"
    static let markerName = "ktstack-ca-constraints.json"
    static let organization = "mkcert development CA"

    public enum Coverage: Equatable, Sendable {
        case none
        case unrestricted
        case restricted([String])

        public func covers(_ tld: String) -> Bool {
            switch self {
            case .none: false
            case .unrestricted: true
            case let .restricted(tlds): tlds.contains(tld)
            }
        }
    }

    struct Marker: Codable {
        let fingerprint: String
        let tlds: [String]
    }

    public static func isEnabled(defaults: UserDefaults = .standard) -> Bool {
        defaults.object(forKey: policyKey) as? Bool ?? true
    }

    public static func currentTLD(defaults: UserDefaults = .standard) -> String {
        let stored = defaults.string(forKey: AppPreferences.tldDefaultsKey) ?? AppPreferences.defaultTLD
        return DNSConstants.isValidTLD(stored) ? stored : AppPreferences.defaultTLD
    }

    public static func permittedTLDs(including tld: String) -> [String] {
        AppPreferences.safeTLDs.contains(tld) ? AppPreferences.safeTLDs : AppPreferences.safeTLDs + [tld]
    }

    public static func coverage(caDir: URL) -> Coverage {
        let cert = caDir.appendingPathComponent("rootCA.pem")
        guard let pem = try? Data(contentsOf: cert) else { return .none }
        guard let raw = try? Data(contentsOf: caDir.appendingPathComponent(markerName)),
              let marker = try? JSONDecoder().decode(Marker.self, from: raw),
              marker.fingerprint == fingerprint(pem: pem) else { return .unrestricted }
        return .restricted(marker.tlds)
    }

    static func fingerprint(pem: Data) -> String? {
        guard let der = RootCAConstraint.pemToDER(pem) else { return nil }
        return SHA256.hash(data: der).map { String(format: "%02x", $0) }.joined()
    }

    static func opensslConfig(tlds: [String], tag: String) -> String {
        let loopback = [
            "permitted;IP:127.0.0.0/255.0.0.0",
            "permitted;IP:::1/ffff:ffff:ffff:ffff:ffff:ffff:ffff:ffff",
        ]
        let permitted = tlds.map { "permitted;DNS:\($0)" } + loopback
        return """
        [req]
        distinguished_name = dn
        prompt = no
        x509_extensions = v3_ca
        [dn]
        O = \(organization)
        OU = KTStack
        CN = KTStack local CA \(tag)
        [v3_ca]
        basicConstraints = critical, CA:TRUE, pathlen:0
        keyUsage = critical, keyCertSign, cRLSign
        subjectKeyIdentifier = hash
        nameConstraints = critical, \(permitted.joined(separator: ", "))

        """
    }
}
