import Foundation

/// Presents dnsmasq as a Service-view row WITHOUT widening the trust boundary: its lifecycle stays
/// in the privileged helper (root-owned launchd job, Phase 4). This wrapper only mirrors status and
/// forwards enable/disable to `DNSAutomationService` (helper when signed, sudo fallback otherwise).
/// There is no direct `:53` control here — the app never binds or kills the DNS port itself.
public final class DnsmasqProxyService: ManagedService, @unchecked Sendable {
    public let kind = ServiceKind.dnsmasq
    public var detail: String { "*.test" }
    public var logsURL: URL? { nil }
    /// Always presentable as a row — the binary is bundled and the helper owns the lifecycle.
    public var isInstalled: Bool { true }

    private let dns: DNSAutomationService

    public init(dns: DNSAutomationService) { self.dns = dns }

    public func start() async throws { await MainActor.run { dns.enable() } }
    public func stop() async throws { await MainActor.run { dns.disable() } }
    public func restart() async throws { await MainActor.run { dns.reset() } }

    /// Status derives from the live DNS automation state (resolver present + no foreign `:53` owner),
    /// so the row reflects reality even on a dev build where the helper isn't approved.
    public func probe() async -> ServiceStatus {
        await MainActor.run {
            switch dns.status {
            case .enabled:    return .running
            case .disabled:   return .stopped
            case .conflict:   return .warning
            case .unknown:    return .stopped
            }
        }
    }
}
