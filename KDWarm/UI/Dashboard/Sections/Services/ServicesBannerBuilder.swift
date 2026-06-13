import SwiftUI
import KDWarmKit

/// A single banner descriptor for the Services view. Identity is the stable `id` (closures aren't
/// Equatable), so SwiftUI can diff the list across refreshes.
struct ServiceBanner: Identifiable {
    let id: String
    let status: ServiceStatus
    let title: String
    let message: String
    var ctaTitle: String? = nil
    var action: (() -> Void)? = nil
}

/// Builds the consolidated error/remediation banners from live state. This is the one place the
/// cross-phase error surfaces are assembled (port-conflict, CA-untrusted, dns/helper, not-installed,
/// service-error-after-retries) so each renders as guidance + a CTA, reused via `ServiceErrorBanner`.
enum ServicesBannerBuilder {
    @MainActor
    static func banners(snapshots: [ServiceSnapshot],
                        dns: DNSAutomationService,
                        caTrusted: Bool,
                        caExists: Bool,
                        onEnableDNS: @escaping () -> Void,
                        onResetDNS: @escaping () -> Void,
                        onOpenTLSSettings: @escaping () -> Void,
                        onRestart: @escaping (ServiceKind) -> Void) -> [ServiceBanner] {
        var result: [ServiceBanner] = []

        // Port / DNS conflict — a foreign process holds :53 (Herd/Valet). Remediation: reset DNS.
        if case .conflict(let proc) = dns.status {
            result.append(ServiceBanner(
                id: "dns-conflict", status: .error,
                title: "DNS port is in use",
                message: "“\(proc)” is holding port 53, so `.test` resolution is blocked. Reset DNS to take it over.",
                ctaTitle: "Reset DNS", action: onResetDNS))
        } else if dns.status == .disabled {
            // helper/DNS pending — `.test` won't resolve until DNS is enabled (helper or sudo fallback).
            result.append(ServiceBanner(
                id: "dns-off", status: .warning,
                title: "`.test` DNS is off",
                message: "Sites won't resolve until the DNS resolver is enabled (privileged helper or one-time sudo).",
                ctaTitle: "Enable DNS", action: onEnableDNS))
        }

        // CA-untrusted (Phase 5) — HTTPS shows a warning until the local CA is trusted.
        if caExists && !caTrusted {
            result.append(ServiceBanner(
                id: "ca-untrusted", status: .warning,
                title: "Local HTTPS CA isn't trusted",
                message: "Secure `.test` sites will warn until KTStack's root CA is trusted in the System Keychain.",
                ctaTitle: "Open TLS Settings", action: onOpenTLSSettings))
        }

        // A service that exhausted its restart retries — needs a manual restart.
        for snap in snapshots where snap.status == .error {
            result.append(ServiceBanner(
                id: "error-\(snap.kind.rawValue)", status: .error,
                title: "\(snap.displayName) stopped responding",
                message: snap.errorMessage ?? "\(snap.displayName) failed to stay running. Restart it or check its logs.",
                ctaTitle: "Restart", action: { onRestart(snap.kind) }))
        }

        // Only services that are neither installed NOR installable are truly unavailable (e.g. MySQL
        // has no published build yet). Installable engines (Redis/Postgres) get their own per-row
        // Install button, so they don't need a banner.
        let unavailable = snapshots.filter { !$0.isInstalled && !$0.installable }.map(\.displayName)
        if !unavailable.isEmpty {
            result.append(ServiceBanner(
                id: "not-available", status: .info,
                title: "Some services aren't available yet",
                message: "\(unavailable.joined(separator: ", ")) will ship in a later build. Redis and PostgreSQL can be installed now from their row."))
        }
        return result
    }
}
