import SwiftUI
import AppKit
import KDWarmKit

/// Phase 2 ships a single hardcoded demo site. Phase 3 generalises this into a Site Manager
/// with manual registration. The view surfaces the live server state, an Open action, and
/// the TEMPORARY `/etc/hosts` step (automatic DNS arrives in Phase 4).
struct SitesSectionView: View {
    @EnvironmentObject private var server: LocalServerController

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: KDSpacing.space4) {
                demoSiteCard
                hostsNote
            }
            .padding(KDSpacing.space4)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .navigationTitle("Sites")
    }

    private var demoSiteCard: some View {
        VStack(alignment: .leading, spacing: KDSpacing.space2) {
            HStack(spacing: KDSpacing.space2) {
                Image(systemName: "globe").foregroundStyle(Color.accentColor)
                Text(server.demoDomain).font(KDFont.headline)
                StatusPill(server.nginxStatus, text: server.isRunning ? "live" : "offline")
                Spacer()
                Button(server.isRunning ? "Stop" : "Start") { server.toggle() }
                    .disabled(server.isBusy)
                Button("Open") { openSite() }
                    .disabled(!server.isRunning)
                    .keyboardShortcut(.defaultAction)
            }
            Text(server.siteRoot.path)
                .font(KDFont.footnote)
                .foregroundStyle(.secondary)
                .textSelection(.enabled)
            if let error = server.lastError {
                Label(error, systemImage: "exclamationmark.triangle.fill")
                    .font(KDFont.footnote)
                    .foregroundStyle(Color.KDStatus.error)
            }
        }
        .padding(KDSpacing.space3)
        .background(RoundedRectangle(cornerRadius: 10).fill(Color.secondary.opacity(0.06)))
    }

    private var hostsNote: some View {
        VStack(alignment: .leading, spacing: KDSpacing.space1) {
            Label("Temporary DNS setup", systemImage: "info.circle")
                .font(KDFont.subheadline)
            Text("Automatic `.test` DNS arrives in Phase 4. For now, add this line to `/etc/hosts` so the browser can resolve the demo domain:")
                .font(KDFont.footnote)
                .foregroundStyle(.secondary)
            HStack {
                Text("127.0.0.1 \(server.demoDomain)")
                    .font(.system(.footnote, design: .monospaced))
                    .textSelection(.enabled)
                Spacer()
                Button("Copy") {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString("127.0.0.1 \(server.demoDomain)", forType: .string)
                }
                .buttonStyle(.borderless)
                .font(KDFont.footnote)
            }
            .padding(KDSpacing.space2)
            .background(RoundedRectangle(cornerRadius: 6).fill(Color.secondary.opacity(0.08)))
            Text("Run: echo \"127.0.0.1 \(server.demoDomain)\" | sudo tee -a /etc/hosts")
                .font(.system(.caption2, design: .monospaced))
                .foregroundStyle(.tertiary)
                .textSelection(.enabled)
        }
        .padding(KDSpacing.space3)
        .background(RoundedRectangle(cornerRadius: 10).fill(Color.secondary.opacity(0.04)))
    }

    private func openSite() {
        guard let url = URL(string: "http://\(server.demoDomain)/") else { return }
        NSWorkspace.shared.open(url)
    }
}
