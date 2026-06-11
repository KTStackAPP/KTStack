import SwiftUI
import AppKit
import KDWarmKit

/// Menu-bar dropdown skeleton (design-guidelines §5.2, wireframe `menubar-dropdown`).
/// Header · placeholder service rows · footer actions. All data is static sample data;
/// real service state binds in Phase 6.
struct MenuBarContentView: View {
    @Environment(\.openWindow) private var openWindow
    @EnvironmentObject private var server: LocalServerController

    /// Placeholder rows for services not yet supervised (real supervision: Phase 6).
    private let placeholders = Service.sample.filter { !["Nginx", "PHP-FPM"].contains($0.name) }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Divider().padding(.vertical, KDSpacing.space1)
            servicesSection
            Divider().padding(.vertical, KDSpacing.space1)
            footer
        }
        .padding(KDSpacing.space2)
        .frame(width: 324)
    }

    private var header: some View {
        HStack(spacing: KDSpacing.space2) {
            Image(systemName: "bolt.horizontal.circle")
                .font(.system(size: 18))
                .foregroundStyle(Color.accentColor)
            VStack(alignment: .leading, spacing: 1) {
                Text("KDWarm").font(KDFont.headline)
                Text(headerSubtitle)
                    .font(KDFont.footnote)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button("Stop All") { server.stop() }
                .buttonStyle(.borderless)
                .font(KDFont.footnote)
                .disabled(!server.isRunning || server.isBusy)
        }
        .padding(.horizontal, KDSpacing.space1)
    }

    private var headerSubtitle: String {
        if server.isBusy { return "v0.1.0 · working…" }
        return server.isRunning ? "v0.1.0 · web server running" : "v0.1.0 · web server stopped"
    }

    private var servicesSection: some View {
        VStack(alignment: .leading, spacing: KDSpacing.space1) {
            Text("Services")
                .font(KDFont.footnote)
                .foregroundStyle(.tertiary)
                .padding(.horizontal, KDSpacing.space1)

            // Live, supervised services (this phase). The Nginx row carries the master
            // toggle that boots/stops the whole php-fpm + nginx slice.
            liveRow(name: "Nginx", symbol: "arrow.triangle.branch", detail: ":80",
                    status: server.nginxStatus, isMasterToggle: true)
            liveRow(name: "PHP-FPM", symbol: "chevron.left.forwardslash.chevron.right",
                    detail: "8.4", status: server.phpStatus, isMasterToggle: false)

            ForEach(placeholders) { service in
                serviceRow(service.name, symbol: service.symbolName, detail: service.detail,
                           status: service.status, toggleOn: .constant(service.isOn), enabled: false)
            }
        }
    }

    /// A live service row bound to the controller. The master row's toggle drives start/stop.
    private func liveRow(name: String, symbol: String, detail: String,
                         status: ServiceStatus, isMasterToggle: Bool) -> some View {
        let binding = Binding<Bool>(
            get: { server.isRunning },
            set: { _ in server.toggle() })
        return serviceRow(name, symbol: symbol, detail: detail, status: status,
                          toggleOn: binding, enabled: isMasterToggle && !server.isBusy)
    }

    private func serviceRow(_ name: String, symbol: String, detail: String,
                            status: ServiceStatus, toggleOn: Binding<Bool>, enabled: Bool) -> some View {
        HStack(spacing: KDSpacing.space2) {
            Image(systemName: symbol)
                .frame(width: 18)
                .foregroundStyle(.secondary)
            Text(name).font(KDFont.body)
            Spacer()
            StatusPill(status, text: detail)
            Toggle("", isOn: toggleOn)
                .toggleStyle(.switch)
                .controlSize(.mini)
                .labelsHidden()
                .disabled(!enabled)
        }
        .padding(.vertical, KDSpacing.space1)
        .padding(.horizontal, KDSpacing.space1)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(name), \(status.label), \(detail)")
    }

    private var footer: some View {
        VStack(spacing: 0) {
            footerButton("Open Dashboard…", systemImage: "rectangle.split.3x1", shortcut: "⌘D") {
                AppActivationPolicy.activateRegular()
                openWindow(id: DashboardWindow.windowID)
            }
            settingsFooterItem
            footerButton("Quit KDWarm", systemImage: "power", shortcut: "⌘Q") {
                NSApp.terminate(nil)
            }
        }
    }

    /// Opening the `Settings` scene from an accessory menu-bar app is version-specific:
    /// the legacy `showSettingsWindow:` selector was removed in macOS 14, so on 14+ we
    /// use `SettingsLink` (with a pre-tap activation flip) and keep the selector only as
    /// the macOS 13 fallback. Both promote to `.regular` so the window can take focus.
    @ViewBuilder
    private var settingsFooterItem: some View {
        if #available(macOS 14.0, *) {
            SettingsLink {
                footerRowLabel("Settings…", systemImage: "gearshape", shortcut: "⌘,")
            }
            .buttonStyle(.plain)
            .simultaneousGesture(TapGesture().onEnded {
                AppActivationPolicy.activateRegular()
            })
        } else {
            footerButton("Settings…", systemImage: "gearshape", shortcut: "⌘,") {
                AppActivationPolicy.activateRegular()
                NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
            }
        }
    }

    private func footerButton(_ title: String,
                              systemImage: String,
                              shortcut: String,
                              action: @escaping () -> Void) -> some View {
        Button(action: action) {
            footerRowLabel(title, systemImage: systemImage, shortcut: shortcut)
        }
        .buttonStyle(.plain)
    }

    private func footerRowLabel(_ title: String,
                                systemImage: String,
                                shortcut: String) -> some View {
        HStack(spacing: KDSpacing.space2) {
            Image(systemName: systemImage).frame(width: 18).foregroundStyle(.secondary)
            Text(title).font(KDFont.body)
            Spacer()
            Text(shortcut).font(KDFont.footnote).foregroundStyle(.tertiary)
        }
        .contentShape(Rectangle())
        .padding(.vertical, KDSpacing.space1)
        .padding(.horizontal, KDSpacing.space1)
    }
}
