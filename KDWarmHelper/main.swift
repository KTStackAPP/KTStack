import Foundation

/// Privileged helper entry point. Stands up the Mach-service XPC listener; every incoming
/// connection is gated by `HelperSignatureValidator` (audit-token + pinned code requirement)
/// before the DNS surface is exported. On the dev/ad-hoc build (no Team ID) the validator trusts
/// nobody, so the helper accepts no connections — the live privileged path is gated on Phase 9 signing.
/// Bumped to 0.2.0: the DNS XPC methods are now TLD-parameterized and `setTLD` was added
/// (configurable TLD). The app reconciles against this version after a helper update.
let helperBundleVersion = "0.2.0"

/// The exported XPC object — thin delegation to `HelperDNSManager`. The whole privileged surface.
final class HelperService: NSObject, HelperXPCProtocol {
    private let dns = HelperDNSManager()
    private let ca = HelperCAManager()

    func ping(reply: @escaping (String) -> Void) { reply(helperBundleVersion) }
    func helperVersion(reply: @escaping (String) -> Void) { reply(helperBundleVersion) }

    func enableDNS(tld: String, reply: @escaping (Bool, String?) -> Void) {
        let r = dns.enableDNS(tld: tld); reply(r.0, r.1)
    }
    func disableDNS(tld: String, reply: @escaping (Bool, String?) -> Void) {
        let r = dns.disableDNS(tld: tld); reply(r.0, r.1)
    }
    func resetDNS(tld: String, reply: @escaping (Bool, String?) -> Void) {
        let r = dns.resetDNS(tld: tld); reply(r.0, r.1)
    }
    func setTLD(old: String, new: String, reply: @escaping (Bool, String?) -> Void) {
        let r = dns.setTLD(old: old, new: new); reply(r.0, r.1)
    }
    func dnsStatus(tld: String, reply: @escaping (Bool, Bool, String?) -> Void) {
        let s = dns.status(tld: tld); reply(s.resolverPresent, s.dnsmasqRunning, s.conflict)
    }

    func installRootCA(pemData: Data, reply: @escaping (Bool, String?) -> Void) {
        let r = ca.installRootCA(pemData: pemData); reply(r.0, r.1)
    }
    func removeRootCA(certSHA1: String, reply: @escaping (Bool, String?) -> Void) {
        let r = ca.removeRootCA(certSHA1: certSHA1); reply(r.0, r.1)
    }
}

final class HelperListenerDelegate: NSObject, NSXPCListenerDelegate {
    func listener(_ listener: NSXPCListener,
                  shouldAcceptNewConnection connection: NSXPCConnection) -> Bool {
        guard HelperSignatureValidator.isTrustedClient(connection) else { return false }
        connection.exportedInterface = NSXPCInterface(with: HelperXPCProtocol.self)
        connection.exportedObject = HelperService()
        connection.resume()
        return true
    }
}

let delegate = HelperListenerDelegate()
let listener = NSXPCListener(machServiceName: HelperIdentity.machServiceName)
listener.delegate = delegate
listener.resume()
dispatchMain()
