import Foundation

/// XPC contract between the app (client) and the privileged helper (root). This is the WHOLE
/// privileged attack surface — keep it minimal and DNS/resolver + CA-scoped. The TLD is configurable
/// (Phase 5): because the helper compiles its OWN copy of `DNSConstants`, the live TLD must cross the
/// boundary at call time, so the DNS methods take it as an argument rather than baking a constant.
///
/// Reply types are ObjC-compatible primitives (no custom structs across the boundary); the app
/// rebuilds `HelperDNSStatus` from the `dnsStatus` reply tuple.
@objc public protocol HelperXPCProtocol {
    /// Liveness probe; replies with the helper's bundle version.
    func ping(reply: @escaping (String) -> Void)

    /// Write `/etc/resolver/<tld>` + start dnsmasq so `*.<tld> → 127.0.0.1`. Idempotent.
    func enableDNS(tld: String, reply: @escaping (Bool, String?) -> Void)

    /// Remove `/etc/resolver/<tld>` + stop dnsmasq. Idempotent.
    func disableDNS(tld: String, reply: @escaping (Bool, String?) -> Void)

    /// Reconcile actual vs desired for `tld`: purge a stale resolver, restart dnsmasq, re-write it.
    func resetDNS(tld: String, reply: @escaping (Bool, String?) -> Void)

    /// Change the dev TLD in ONE root op: remove `/etc/resolver/<old>`, write `/etc/resolver/<new>`,
    /// rewrite the dnsmasq wildcard to `<new>`, restart dnsmasq, flush the DNS cache. A single combined
    /// op (not enable-new + disable-old) so the OLD resolver is always removed — an orphaned
    /// `/etc/resolver/<old>` would keep routing a dead TLD into system DNS. nginx/php keep running.
    func setTLD(old: String, new: String, reply: @escaping (Bool, String?) -> Void)

    /// Status for `tld`: resolver present? dnsmasq running? name of a process holding :53, else nil.
    func dnsStatus(tld: String, reply: @escaping (Bool, Bool, String?) -> Void)

    /// Helper bundle version — used to reconcile after an app/helper update.
    func helperVersion(reply: @escaping (String) -> Void)

    // MARK: CA trust (Phase 5) — the helper accepts ONLY the PUBLIC root cert bytes and performs a
    // fixed System-Keychain trust operation. It never receives or stores the CA private key, and
    // there is no arbitrary-path/keychain endpoint. This is the entire privileged surface — nothing
    // beyond DNS + CA is ever added.

    /// Install the given PUBLIC root cert as a trusted root in the System Keychain.
    func installRootCA(pemData: Data, reply: @escaping (Bool, String?) -> Void)

    /// Remove a SPECIFIC root CA from the System Keychain, identified by its SHA-1 fingerprint
    /// (hex, no separators). Exact-match by hash — never a name prefix — so a co-resident mkcert
    /// CA (the user's own) is never deleted by mistake.
    func removeRootCA(certSHA1: String, reply: @escaping (Bool, String?) -> Void)
}

/// App-side view of the helper's DNS state, rebuilt from the `dnsStatus` reply.
public struct HelperDNSStatus: Sendable, Equatable {
    public let resolverPresent: Bool
    public let dnsmasqRunning: Bool
    /// Non-nil when another process holds `127.0.0.1:53` (e.g. Herd/Valet).
    public let conflictProcess: String?

    public init(resolverPresent: Bool, dnsmasqRunning: Bool, conflictProcess: String?) {
        self.resolverPresent = resolverPresent
        self.dnsmasqRunning = dnsmasqRunning
        self.conflictProcess = conflictProcess
    }

    /// DNS is fully up: resolver written, dnsmasq running, no port conflict.
    public var isHealthy: Bool { resolverPresent && dnsmasqRunning && conflictProcess == nil }

    public static let unknown = HelperDNSStatus(resolverPresent: false, dnsmasqRunning: false, conflictProcess: nil)
}
