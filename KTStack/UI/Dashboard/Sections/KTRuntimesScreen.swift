import SwiftUI
import KTStackKit

struct KTRuntimesScreen: View {
    @EnvironmentObject private var runtimes: RuntimeManager
    @EnvironmentObject private var server: LocalServerController

    @State private var tab: RuntimeLanguage = .php
    @State private var showInstall = false
    @State private var editingIni: VersionRef?
    @State private var managingExt: VersionRef?
    @State private var pendingUninstall: PendingUninstall?

    private struct VersionRef: Identifiable { let version: String; var id: String { version } }
    private struct PendingUninstall: Identifiable {
        let language: RuntimeLanguage
        let version: String
        let inUseBy: [String]
        var id: String { "\(language.rawValue)-\(version)" }
    }

    private struct Entry: Identifiable {
        let version: String
        let state: KTRuntimeState
        let release: RuntimeRelease?
        var id: String { version }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header.padding(.horizontal, KTSpacing.screenGutter).padding(.top, 18)
            Text("Install and switch language versions per site.")
                .font(.system(size: 13.5)).foregroundStyle(Color(hex: 0x8E8E93))
                .padding(.horizontal, KTSpacing.screenGutter).padding(.top, 6)

            ScrollView {
                KTListContainer { rows }
                    .padding(.horizontal, KTSpacing.screenGutter)
                    .padding(.top, 16)
                    .padding(.bottom, 24)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(KTColor.contentBg)
        .sheet(isPresented: $showInstall) { RuntimeDownloadSheet() }
        .sheet(item: $editingIni) { PHPIniEditorSheet(version: $0.version) }
        .sheet(item: $managingExt) { PHPExtensionsSheet(version: $0.version) }
        .alert(item: $pendingUninstall, content: uninstallAlert)
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
        let items = entries(tab)
        return VStack(spacing: 0) {
            ForEach(Array(items.enumerated()), id: \.element.id) { index, entry in
                KTRuntimeRow(
                    language: tab,
                    version: entry.version,
                    state: entry.state,
                    downloadFraction: downloadFraction(tab, entry.version),
                    onSetDefault: { runtimes.setGlobalDefault(tab, entry.version) },
                    onInstall: { if let release = entry.release { runtimes.install(release) } },
                    onCancel: { runtimes.cancel(tab) },
                    onUninstall: { requestUninstall(tab, entry.version) },
                    onEditIni: tab == .php ? { editingIni = VersionRef(version: entry.version) } : nil,
                    onManageExtensions: tab == .php ? { managingExt = VersionRef(version: entry.version) } : nil)
                if index < items.count - 1 {
                    Rectangle().fill(KTColor.sepFaint).frame(height: 0.5).padding(.leading, 18)
                }
            }
        }
    }

    private func entries(_ lang: RuntimeLanguage) -> [Entry] {
        let installed = (runtimes.installed[lang] ?? [])
            .sorted { $0.compare($1, options: .numeric) == .orderedDescending }
        let def = runtimes.defaultVersion(lang)
        var list = installed.map { Entry(version: $0, state: $0 == def ? .active : .installed, release: nil) }
        list += runtimes.availableReleases(lang).map { Entry(version: $0.version, state: .available, release: $0) }
        return list
    }

    private func downloadFraction(_ lang: RuntimeLanguage, _ version: String) -> Double? {
        guard let download = runtimes.downloads[lang], download.version == version else { return nil }
        return download.fraction
    }

    private func requestUninstall(_ lang: RuntimeLanguage, _ version: String) {
        let inUse = lang == .php
            ? server.registry.sites.filter { $0.type == .php && $0.phpVersion == version }.map(\.domain)
            : []
        pendingUninstall = PendingUninstall(language: lang, version: version, inUseBy: inUse)
    }

    private func uninstallAlert(_ p: PendingUninstall) -> Alert {
        let name = "\(p.language.displayName) \(p.version)"
        guard !p.inUseBy.isEmpty else {
            return Alert(title: Text("Remove \(name)?"),
                         message: Text("This deletes the downloaded runtime. You can reinstall it anytime."),
                         primaryButton: .destructive(Text("Remove")) { performUninstall(p) },
                         secondaryButton: .cancel())
        }
        let n = p.inUseBy.count
        return Alert(title: Text("Remove \(name)?"),
                     message: Text("In use by \(n) site\(n == 1 ? "" : "s"): \(p.inUseBy.joined(separator: ", "))."),
                     primaryButton: .destructive(Text("Remove anyway")) { performUninstall(p) },
                     secondaryButton: .cancel())
    }

    private func performUninstall(_ p: PendingUninstall) {
        runtimes.uninstall(p.language, p.version)
        if p.language == .php { server.reconcileAfterRuntimeChange() }
    }
}
