import KTPluginKit
import SwiftUI

extension RuntimesScreen {
    @ViewBuilder
    func webServerGroup(_ category: RuntimesCategory) -> some View {
        group("Installed", count: 1, isEmpty: false, empty: { EmptyView() }) {
            switch category {
            case .apache: apacheRow
            default: nginxRow
            }
        }
    }

    private var nginxRow: some View {
        webEngineRow(name: "Nginx", subtitle: "Front terminator · default per-site engine") {
            KTBadge(text: "Bundled", tint: KTIconTint.globe, radius: 8)
        }
    }

    private var apacheRow: some View {
        webEngineRow(
            name: "Apache \(vm.webEngine.apacheVersion)",
            subtitle: vm.webEngine.error ?? "Per-site engine · mod_proxy_fcgi to PHP-FPM · .htaccess"
        ) { apacheControl }
    }

    private func webEngineRow(name: String, subtitle: String, @ViewBuilder trailing: () -> some View) -> some View {
        HStack(spacing: 14) {
            KTIconTile(tint: KTIconTint.globe, size: 40, radius: 11) {
                Image(systemName: "server.rack").font(.system(size: 18, weight: .medium))
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(name).font(KTType.rowName).foregroundStyle(KTColor.ink)
                Text(subtitle).font(KTType.sub).foregroundStyle(KTColor.muted).lineLimit(1).truncationMode(.tail)
            }
            Spacer(minLength: 8)
            trailing()
        }
        .padding(.vertical, 15).padding(.horizontal, 18)
    }

    @ViewBuilder
    private var apacheControl: some View {
        if vm.webEngine.installing {
            ProgressView().controlSize(.small).frame(width: 40)
        } else if vm.webEngine.installed {
            KTBadge(text: "Installed", tint: KTIconTint.globe, radius: 8)
        } else {
            KTButton(title: "Install", systemImage: "arrow.down.circle", kind: .primary) { vm.installApache() }
        }
    }
}
