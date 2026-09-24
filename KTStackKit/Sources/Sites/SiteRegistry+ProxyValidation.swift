import Foundation
import KTStackCore

extension SiteRegistry {
    static let loopbackHosts: Set<String> = ["127.0.0.1", "localhost", "::1", "[::1]", "0.0.0.0"]
    static let frontPorts: Set<Int> = [80, 443]

    public func validateProxyTarget(_ target: ProxyTarget, for site: Site?, domain: String? = nil) throws {
        let host = target.host.lowercased()
        if let own = site?.domain ?? domain, host == own {
            throw RegistryError.proxyTargetLoopsToSite(own)
        }
        if Self.loopbackHosts.contains(host), Self.frontPorts.contains(target.port) {
            throw RegistryError.proxyTargetIsFront(target.displayString)
        }
        if sites.contains(where: { $0.id != site?.id && ($0.domain == host || $0.aliases.contains(host)) }) {
            throw RegistryError.proxyTargetLoopsToSite(host)
        }
    }
}
