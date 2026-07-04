import Foundation

public final class DnsmasqProxyService: ManagedService, @unchecked Sendable {
    public let kind = ServiceKind.dnsmasq
    public var detail: String {
        "*.test"
    }

    public var logsURL: URL? {
        nil
    }

    public var isInstalled: Bool {
        true
    }

    private let dns: DNSAutomationService

    public init(dns: DNSAutomationService) {
        self.dns = dns
    }

    public func start() async throws {
        try await dns.enableAndWait()
    }

    public func stop() async throws {
        try await dns.disableAndWait()
    }

    public func restart() async throws {
        try await dns.resetAndWait()
    }

    public func probe() async -> ServiceStatus {
        await MainActor.run {
            switch dns.status {
            case .enabled: .running
            case .disabled: .stopped
            case .conflict: .warning
            case .unknown: .stopped
            }
        }
    }
}
