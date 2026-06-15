import SwiftUI
import KDWarmKit

struct ServicesSectionView: View {

    var onNavigate: (SidebarItem) -> Void = { _ in }

    var onOpenLogs: (String?) -> Void = { _ in }

    @EnvironmentObject private var services: ServiceManager
    @EnvironmentObject private var dns: DNSAutomationService

    private let paths = AppSupportPaths()

    
    @State private var caExists = false
    @State private var caTrusted = false

    var body: some View {
        VStack(spacing: 0) {
            toolbar
            Divider()
            ScrollView {
                LazyVStack(spacing: 0) {
                    if !banners.isEmpty {
                        VStack(spacing: KDSpacing.space2) {
                            ForEach(banners) { banner in
                                ServiceErrorBanner(status: banner.status, title: banner.title,
                                                   message: banner.message, ctaTitle: banner.ctaTitle,
                                                   action: banner.action)
                            }
                        }
                        .padding(KDSpacing.space2)
                    }
                    ForEach(services.snapshots) { snapshot in
                        ServiceRowView(
                            snapshot: snapshot,
                            canToggle: snapshot.kind != .phpFpm,
                            onToggle: { services.toggle(snapshot.kind) },
                            onRestart: { services.restart(snapshot.kind) },
                            onOpenLogs: { onOpenLogs(Self.logSourceID(for: snapshot.kind)) },
                            onInstall: { services.install(snapshot.kind) },
                            onCancelInstall: { services.cancelInstall(snapshot.kind) },
                            onResetData: { services.resetData(snapshot.kind) })
                        Divider()
                    }
                }
            }
        }
        .navigationTitle("Services")
        .task { await refreshCATrustLoop() }
    }


    private func refreshCATrustLoop() async {
        let caCert = paths.caRootCert
        while !Task.isCancelled {
            let exists = FileManager.default.fileExists(atPath: caCert.path)
            var trusted = false
            if exists {
                trusted = await Task.detached {
                    CATrustService.isTrustedInSystemKeychain(caCert: caCert)
                }.value
            }
            if exists != caExists { caExists = exists }
            if trusted != caTrusted { caTrusted = trusted }
            try? await Task.sleep(nanoseconds: 2_000_000_000)
        }
    }

    private var toolbar: some View {
        HStack(spacing: KDSpacing.space2) {
            Button("Start All", systemImage: "play.fill") { services.startAll() }
            Button("Stop All", systemImage: "stop.fill") { services.stopAll() }
            Spacer()
            Text("\(runningCount) of \(services.snapshots.count) running")
                .font(KDFont.footnote)
                .foregroundStyle(.secondary)
        }
        .padding(KDSpacing.space2)
    }

    private var runningCount: Int {
        services.snapshots.filter { $0.status == .running }.count
    }


    private static func logSourceID(for kind: ServiceKind) -> String? {
        switch kind {
        case .nginx:    return "nginx-error"
        case .mysql:    return "mysql"
        case .postgres: return "postgres"
        case .redis:    return "redis"
        case .mongodb:  return "mongodb"
        case .mailpit:  return "mailpit"
        case .phpFpm, .dnsmasq: return nil
        }
    }

    private var banners: [ServiceBanner] {
        ServicesBannerBuilder.banners(
            snapshots: services.snapshots,
            dns: dns,
            caTrusted: caTrusted,
            caExists: caExists,
            onEnableDNS: { dns.enable() },
            onResetDNS: { dns.reset() },
            onOpenTLSSettings: { onNavigate(.settings) },
            onRestart: { services.restart($0) })
    }
}
