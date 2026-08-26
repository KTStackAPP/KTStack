import KTPlatformContracts
import KTPluginKit
import SwiftUI

enum ServiceBannerSeverity {
    case error, warning, info

    var symbolName: String {
        switch self {
        case .error: "xmark.octagon.fill"
        case .warning: "exclamationmark.triangle.fill"
        case .info: "info.circle"
        }
    }

    var color: Color {
        switch self {
        case .error: .KDStatus.error
        case .warning: .KDStatus.warning
        case .info: .KDStatus.info
        }
    }
}

struct ServiceBanner: Identifiable {
    let id: String
    let severity: ServiceBannerSeverity
    let title: String
    let message: String
    var ctaTitle: String?
    var action: (() -> Void)?
}

struct ServiceBannerActions {
    let onEnableDNS: () -> Void
    let onResetDNS: () -> Void
    let onOpenTLSSettings: () -> Void
    let onOpenLoginItems: () -> Void
    let onRestart: (ServiceID) -> Void
}

enum ServicesBannerBuilder {
    static func banners(
        services: [ServiceState],
        dns: DNSResolverState,
        ca: CATrustState,
        actions: ServiceBannerActions
    ) -> [ServiceBanner] {
        var result: [ServiceBanner] = []

        if case let .conflict(proc) = dns.status {
            result.append(ServiceBanner(
                id: "dns-conflict", severity: .error,
                title: "DNS port is in use",
                message: "“\(proc)” is holding port 53, so `.test` resolution is blocked. Reset DNS to take it over.",
                ctaTitle: "Reset DNS", action: actions.onResetDNS
            ))
        } else if let error = dns.lastError, dns.status == .disabled {
            let needsApproval = dns.helperNeedsApproval
            result.append(ServiceBanner(
                id: "dns-error", severity: .error,
                title: "Couldn't enable `.test` DNS",
                message: dns.usesHelper
                    ? "\(error) Approve KTStack's helper in System Settings > General > Login Items & Extensions, then enable DNS again."
                    : error,
                ctaTitle: needsApproval ? "Open Login Items" : "Try again",
                action: needsApproval ? actions.onOpenLoginItems : actions.onEnableDNS
            ))
        } else if dns.status == .disabled, dns.helperNeedsApproval {
            result.append(ServiceBanner(
                id: "dns-approve", severity: .warning,
                title: "Approve KTStack's DNS helper",
                message: "macOS needs you to allow KTStack's background helper before `.test` DNS can start. "
                    + "Open Login Items, turn on KTStack under “Allow in the Background”, then enable DNS.",
                ctaTitle: "Open Login Items", action: actions.onOpenLoginItems
            ))
        } else if dns.status == .disabled {
            result.append(ServiceBanner(
                id: "dns-off", severity: .warning,
                title: "`.test` DNS is off",
                message: "Sites won't resolve until the DNS resolver is enabled (privileged helper or one-time sudo).",
                ctaTitle: "Enable DNS", action: actions.onEnableDNS
            ))
        }

        if ca.exists, !ca.trusted {
            result.append(ServiceBanner(
                id: "ca-untrusted", severity: .warning,
                title: "Local HTTPS CA isn't trusted",
                message: "Secure `.test` sites will warn until KTStack's root CA is trusted in the System Keychain.",
                ctaTitle: "Open TLS Settings", action: actions.onOpenTLSSettings
            ))
        }

        for service in services where service.health == .error {
            result.append(ServiceBanner(
                id: "error-\(service.id.rawValue)", severity: .error,
                title: "\(service.displayName) stopped responding",
                message: service.errorMessage ?? "\(service.displayName) failed to stay running. Restart it or check its logs.",
                ctaTitle: "Restart", action: { actions.onRestart(service.id) }
            ))
        }

        let unavailable = services.filter { !$0.isInstalled && !$0.installable }.map(\.displayName)
        if !unavailable.isEmpty {
            result.append(ServiceBanner(
                id: "not-available", severity: .info,
                title: "Some services aren't available yet",
                message: "\(unavailable.joined(separator: ", ")) will ship in a later build. Redis and PostgreSQL can be installed now from their row."
            ))
        }
        return result
    }
}
