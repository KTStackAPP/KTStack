import Foundation
import KTPlatformContracts
import KTStackCore
import SwiftUI

enum RuntimeEntryState {
    case active, installed, available
}

@MainActor
final class RuntimesViewModel: ObservableObject {
    struct Entry: Identifiable {
        let version: String
        let state: RuntimeEntryState
        let release: RuntimeRelease?
        var id: String {
            version
        }
    }

    struct UninstallPrompt {
        let title: String
        let message: String
        let okLabel: String
    }

    @Published private(set) var state = RuntimeState()
    @Published private(set) var webEngine: WebEngineState

    private let runtimes: any RuntimeManaging
    private let webEngineProvider: any WebEngineProvisioning
    private let phpSites: any PHPSiteRuntimeProviding
    private var tasks: [Task<Void, Never>] = []

    init(
        runtimes: any RuntimeManaging,
        webEngine: any WebEngineProvisioning,
        phpSites: any PHPSiteRuntimeProviding
    ) {
        self.runtimes = runtimes
        webEngineProvider = webEngine
        self.phpSites = phpSites
        state = runtimes.state
        self.webEngine = webEngine.webEngineState

        tasks.append(Task { [weak self] in
            for await next in runtimes.states() {
                self?.state = next
            }
        })
        tasks.append(Task { [weak self] in
            for await next in webEngine.webEngineStates() {
                self?.webEngine = next
            }
        })
    }

    deinit {
        for task in tasks {
            task.cancel()
        }
    }

    func entries(_ lang: RuntimeLanguage) -> [Entry] {
        installedEntries(lang) + availableEntries(lang)
    }

    // Installed: default trước, còn lại numeric giảm dần.
    func installedEntries(_ lang: RuntimeLanguage) -> [Entry] {
        let def = state.defaults[lang]
        let installed = (state.installed[lang] ?? [])
            .sorted { lhs, rhs in
                if lhs == def { return true }
                if rhs == def { return false }
                return lhs.compare(rhs, options: .numeric) == .orderedDescending
            }
        return installed.map { Entry(version: $0, state: $0 == def ? .active : .installed, release: nil) }
    }

    func availableEntries(_ lang: RuntimeLanguage) -> [Entry] {
        runtimes.availableReleases(lang).map { Entry(version: $0.version, state: .available, release: $0) }
    }

    func railSummary(_ lang: RuntimeLanguage) -> String {
        let installed = state.installed[lang] ?? []
        guard !installed.isEmpty else { return "Not installed" }
        let def = state.defaults[lang] ?? installed.first ?? ""
        return "\(installed.count) installed · \(def) default"
    }

    /// Site đang dùng version PHP (Node không có per-version site count).
    func sites(for version: String) -> [String] {
        phpSites.sitesUsingPHP(version: version)
    }

    func metaLine(_ lang: RuntimeLanguage, _ entry: Entry) -> String {
        switch lang {
        case .php:
            let count = sites(for: entry.version).count
            let sitesPhrase = count == 1 ? "1 site" : "\(count) sites"
            var line = entry.state == .active
                ? "Default for new sites and terminals · \(sitesPhrase)"
                : (count == 0 ? "Not used by any site" : sitesPhrase)
            if isEndOfLife(.php, entry.version) { line += " · no security updates" }
            return line
        case .node:
            return entry.state == .active
                ? "Default for terminals · sites run their own server"
                : "Installed"
        }
    }

    func downloadFraction(_ lang: RuntimeLanguage, _ version: String) -> Double? {
        guard let download = state.downloads[lang], download.version == version else { return nil }
        return download.fraction
    }

    func download(_ lang: RuntimeLanguage, _ version: String) -> RuntimeDownloadProgress? {
        guard let download = state.downloads[lang], download.version == version else { return nil }
        return download
    }

    func isDownloading(_ lang: RuntimeLanguage) -> Bool {
        guard let download = state.downloads[lang] else { return false }
        return download.error == nil
    }

    func availableReleases(_ lang: RuntimeLanguage) -> [RuntimeRelease] {
        runtimes.availableReleases(lang)
    }

    func isEndOfLife(_ lang: RuntimeLanguage, _ version: String) -> Bool {
        runtimes.isEndOfLife(lang, version)
    }

    func install(_ release: RuntimeRelease) {
        runtimes.install(release)
    }

    func cancel(_ lang: RuntimeLanguage) {
        runtimes.cancel(lang)
    }

    func setDefault(_ lang: RuntimeLanguage, _ version: String) {
        runtimes.setGlobalDefault(lang, version)
    }

    func uninstall(_ lang: RuntimeLanguage, _ version: String) {
        runtimes.uninstall(lang, version)
        if lang == .php { phpSites.reconcileAfterRuntimeChange() }
    }

    func uninstallPrompt(_ lang: RuntimeLanguage, _ version: String) -> UninstallPrompt {
        let inUse = lang == .php ? phpSites.sitesUsingPHP(version: version) : []
        let name = "\(lang.displayName) \(version)"
        let message: String
        if inUse.isEmpty {
            message = "This deletes the downloaded runtime. You can reinstall it anytime."
        } else {
            let count = inUse.count
            message = "In use by \(count) site\(count == 1 ? "" : "s"): \(inUse.joined(separator: ", "))."
        }
        return UninstallPrompt(
            title: "Remove \(name)?",
            message: message,
            okLabel: inUse.isEmpty ? "Remove" : "Remove anyway"
        )
    }

    func installApache() {
        webEngineProvider.installApache()
    }
}
