import SwiftUI
import KDWarmKit

/// Runtimes dashboard (design wireframe `dashboard-runtimes`): a Bento grid of per-language cards
/// (installed versions, Set default, inline install/progress) + an "Install Version…" sheet. Binds
/// to `RuntimeManager` so installed/download state refreshes live.
struct RuntimesSectionView: View {
    @EnvironmentObject private var runtimes: RuntimeManager
    @State private var showInstall = false
    @State private var editingIni: EditingIni?
    /// `php -m` per installed PHP version, loaded off-main (the probe runs the binary).
    @State private var phpExtensions: [String: [String]] = [:]

    /// Identifiable wrapper so the editor sheet binds to which PHP version was tapped.
    private struct EditingIni: Identifiable { let version: String; var id: String { version } }

    private let columns = [GridItem(.flexible(), spacing: KDSpacing.space3),
                           GridItem(.flexible(), spacing: KDSpacing.space3)]

    var body: some View {
        VStack(spacing: 0) {
            toolbar
            Divider()
            ScrollView {
                LazyVGrid(columns: columns, spacing: KDSpacing.space3) {
                    ForEach(RuntimeLanguage.allCases) { lang in card(lang) }
                }
                .padding(KDSpacing.space3)
            }
        }
        .navigationTitle("Runtimes")
        .sheet(isPresented: $showInstall) { RuntimeDownloadSheet() }
        .sheet(item: $editingIni) { PHPIniEditorSheet(version: $0.version) }
        .task(id: runtimes.installed[.php] ?? []) { await loadPHPExtensions() }
    }

    /// Probe `php -m` for each installed PHP version off the main thread, then publish the map.
    private func loadPHPExtensions() async {
        let versions = runtimes.installed[.php] ?? []
        let map = await Task.detached(priority: .utility) {
            Dictionary(uniqueKeysWithValues: versions.map { ($0, PHPModules.list(version: $0)) })
        }.value
        phpExtensions = map
    }

    private var toolbar: some View {
        HStack {
            Text("Languages & versions").font(KDFont.footnote).foregroundStyle(.secondary)
            Spacer()
            Button { showInstall = true } label: { Label("Install Version…", systemImage: "arrow.down.circle") }
        }
        .padding(KDSpacing.space3)
    }

    private func card(_ lang: RuntimeLanguage) -> some View {
        RuntimeCardView(
            language: lang,
            installed: runtimes.installed[lang] ?? [],
            available: runtimes.availableReleases(lang),
            defaultVersion: runtimes.defaultVersion(lang),
            download: runtimes.downloads[lang],
            onSetDefault: { runtimes.setGlobalDefault(lang, $0) },
            onInstall: { runtimes.install($0) },
            onCancel: { runtimes.cancel(lang) },
            onEditIni: lang == .php ? { editingIni = EditingIni(version: $0) } : nil,
            extensions: lang == .php ? phpExtensions : [:])
    }
}
