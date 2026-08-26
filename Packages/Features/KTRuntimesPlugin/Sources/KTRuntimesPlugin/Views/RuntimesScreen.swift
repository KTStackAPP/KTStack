import KTPlatformContracts
import KTPluginKit
import KTStackCore
import SwiftUI

struct RuntimesScreen: View {
    @ObservedObject var vm: RuntimesViewModel
    @ObservedObject var engines: EngineVersionsViewModel
    let phpConfig: any PHPExtensionManaging & PHPIniEditing

    @EnvironmentObject private var feedback: KTFeedbackCenter

    @State private var tab: RuntimeLanguage = .php
    @State private var showInstall = false
    @State private var editingIni: VersionRef?
    @State private var managingExt: VersionRef?

    private struct VersionRef: Identifiable { let version: String; var id: String {
        version
    } }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header.padding(.horizontal, KTSpacing.screenGutter).padding(.top, 18)
            Text("Install and switch language versions per site.")
                .font(.jbMono(13.5)).foregroundStyle(Color(hex: 0x8E8E93))
                .padding(.horizontal, KTSpacing.screenGutter).padding(.top, 6)

            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    KTListContainer { rows }
                    webServerSection
                    KTDatabaseEnginesSection(engines: engines)
                }
                .padding(.horizontal, KTSpacing.screenGutter)
                .padding(.top, 16)
                .padding(.bottom, 24)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(KTColor.contentBg)
        .sheet(isPresented: $showInstall) { RuntimeDownloadSheet(vm: vm) }
        .sheet(item: $editingIni) { PHPIniEditorSheet(version: $0.version, phpConfig: phpConfig) }
        .sheet(item: $managingExt) { PHPExtensionsSheet(version: $0.version, phpConfig: phpConfig) }
        .ktFeedbackHost(feedback)
    }

    private var header: some View {
        HStack(spacing: 14) {
            Text("Runtimes").font(KTType.screenTitle).tracking(KTType.screenTitleTracking).foregroundStyle(KTColor.ink)
            KTSegmentedTabs(items: [.init(value: .php, label: "PHP"), .init(value: .node, label: "Node")], selection: $tab)
            Spacer()
            KTButton(title: "Install Version…", systemImage: "arrow.down.circle", kind: .secondary) { showInstall = true }
        }
    }

    private var rows: some View {
        let items = vm.entries(tab)
        return VStack(spacing: 0) {
            ForEach(Array(items.enumerated()), id: \.element.id) { index, entry in
                KTRuntimeRow(
                    language: tab,
                    version: entry.version,
                    state: entry.state,
                    isEndOfLife: vm.isEndOfLife(tab, entry.version),
                    downloadFraction: vm.downloadFraction(tab, entry.version),
                    onSetDefault: {
                        vm.setDefault(tab, entry.version)
                        feedback.toast("\(tab.displayName) \(entry.version) set as default")
                    },
                    onInstall: { if let release = entry.release { vm.install(release) } },
                    onCancel: { vm.cancel(tab) },
                    onUninstall: { requestUninstall(tab, entry.version) },
                    onEditIni: tab == .php ? { editingIni = VersionRef(version: entry.version) } : nil,
                    onManageExtensions: tab == .php ? { managingExt = VersionRef(version: entry.version) } : nil
                )
                if index < items.count - 1 {
                    Rectangle().fill(KTColor.sepFaint).frame(height: 0.5).padding(.leading, 18)
                }
            }
        }
    }

    // Per-site web engine. Nginx is the bundled front + default backend; Apache is on-demand.
    private var webServerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("WEB SERVER")
                .font(KTType.sectionLabel).tracking(KTType.sectionLabelTracking).foregroundStyle(KTColor.faint)
                .padding(.leading, 4)
            KTListContainer {
                VStack(spacing: 0) {
                    engineRow(name: "Nginx", subtitle: "Front terminator + default per-site engine", trailing: bundledBadge)
                    Rectangle().fill(KTColor.sepFaint).frame(height: 0.5).padding(.leading, 18)
                    engineRow(
                        name: "Apache \(vm.webEngine.apacheVersion)",
                        subtitle: vm.webEngine.error ?? "Per-site engine · mod_proxy_fcgi to PHP-FPM · .htaccess",
                        trailing: apacheControl
                    )
                }
            }
        }
    }

    private func engineRow(name: String, subtitle: String, trailing: some View) -> some View {
        HStack(spacing: 14) {
            KTIconTile(tint: KTIconTint.globe, size: 40, radius: 11) {
                Image(systemName: "server.rack").font(.system(size: 18, weight: .medium))
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(name).font(KTType.rowName).foregroundStyle(KTColor.ink)
                Text(subtitle).font(KTType.sub).foregroundStyle(KTColor.muted).lineLimit(1).truncationMode(.tail)
            }
            Spacer(minLength: 8)
            trailing
        }
        .padding(.vertical, 15).padding(.horizontal, 18)
    }

    private var bundledBadge: some View {
        KTBadge(text: "Bundled", tint: KTIconTint.globe, radius: 8)
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

    private func requestUninstall(_ lang: RuntimeLanguage, _ version: String) {
        let prompt = vm.uninstallPrompt(lang, version)
        feedback.confirm(
            title: prompt.title,
            message: prompt.message,
            okLabel: prompt.okLabel,
            danger: true
        ) {
            vm.uninstall(lang, version)
            feedback.toast("Removed \(lang.displayName) \(version)")
        }
    }
}
