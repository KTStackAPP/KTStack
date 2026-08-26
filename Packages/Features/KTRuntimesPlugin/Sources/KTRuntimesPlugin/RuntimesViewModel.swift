import Foundation
import KTPlatformContracts
import KTStackCore
import SwiftUI

@MainActor
final class RuntimesViewModel: ObservableObject {
    struct Entry: Identifiable {
        let version: String
        let state: KTRuntimeState
        let release: RuntimeRelease?
        var id: String { version }
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
            for await next in runtimes.states() { self?.state = next }
        })
        tasks.append(Task { [weak self] in
            for await next in webEngine.webEngineStates() { self?.webEngine = next }
        })
    }

    deinit {
        for task in tasks { task.cancel() }
    }

    func entries(_ lang: RuntimeLanguage) -> [Entry] {
        let installed = (state.installed[lang] ?? [])
            .sorted { $0.compare($1, options: .numeric) == .orderedDescending }
        let def = state.defaults[lang]
        var list = installed.map { Entry(version: $0, state: $0 == def ? .active : .installed, release: nil) }
        list += runtimes.availableReleases(lang).map { Entry(version: $0.version, state: .available, release: $0) }
        return list
    }

    func downloadFraction(_ lang: RuntimeLanguage, _ version: String) -> Double? {
        guard let download = state.downloads[lang], download.version == version else { return nil }
        return download.fraction
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

    func install(_ release: RuntimeRelease) { runtimes.install(release) }

    func cancel(_ lang: RuntimeLanguage) { runtimes.cancel(lang) }

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

    func installApache() { webEngineProvider.installApache() }
}
