import Foundation
import KTPlatformContracts
import KTStackCore

@MainActor
final class FakeRuntimeManaging: RuntimeManaging {
    var state: RuntimeState
    var releases: [RuntimeRelease] = []
    private(set) var installCalls: [RuntimeRelease] = []
    private(set) var cancelCalls: [RuntimeLanguage] = []
    private(set) var setDefaultCalls: [(RuntimeLanguage, String)] = []
    private(set) var uninstallCalls: [(RuntimeLanguage, String)] = []
    private var continuation: AsyncStream<RuntimeState>.Continuation?
    nonisolated let eol: Set<String>

    init(state: RuntimeState = RuntimeState(), eol: Set<String> = []) {
        self.state = state
        self.eol = eol
    }

    func states() -> AsyncStream<RuntimeState> {
        AsyncStream { continuation in
            self.continuation = continuation
            continuation.yield(self.state)
        }
    }

    func emit(_ next: RuntimeState) {
        state = next
        continuation?.yield(next)
    }

    func availableReleases(_ lang: RuntimeLanguage) -> [RuntimeRelease] {
        releases.filter { $0.language == lang }
    }

    func install(_ release: RuntimeRelease) { installCalls.append(release) }
    func cancel(_ lang: RuntimeLanguage) { cancelCalls.append(lang) }
    func setGlobalDefault(_ lang: RuntimeLanguage, _ version: String) { setDefaultCalls.append((lang, version)) }
    func uninstall(_ lang: RuntimeLanguage, _ version: String) { uninstallCalls.append((lang, version)) }
    nonisolated func isEndOfLife(_ lang: RuntimeLanguage, _ version: String) -> Bool { eol.contains(version) }
}

@MainActor
final class FakeWebEngine: WebEngineProvisioning {
    var webEngineState: WebEngineState
    private(set) var installApacheCalls = 0
    private var continuation: AsyncStream<WebEngineState>.Continuation?

    init(state: WebEngineState = WebEngineState(apacheVersion: "2.4.62", installed: false, installing: false)) {
        webEngineState = state
    }

    func webEngineStates() -> AsyncStream<WebEngineState> {
        AsyncStream { continuation in
            self.continuation = continuation
            continuation.yield(self.webEngineState)
        }
    }

    func emit(_ next: WebEngineState) {
        webEngineState = next
        continuation?.yield(next)
    }

    func installApache() { installApacheCalls += 1 }
}

@MainActor
final class FakePHPSites: PHPSiteRuntimeProviding {
    var sitesByVersion: [String: [String]] = [:]
    private(set) var reconcileCalls = 0

    func sitesUsingPHP(version: String) -> [String] { sitesByVersion[version] ?? [] }
    func reconcileAfterRuntimeChange() { reconcileCalls += 1 }
}

@MainActor
final class FakeEngines: ServiceEngineVersionManaging {
    var engineSnapshots: [ServiceEngineSnapshot]
    private(set) var installCalls: [ServiceEngineRelease] = []
    private(set) var cancelCalls: [ServiceEngineRelease] = []
    private(set) var setActiveCalls: [(ServiceEngine, String)] = []
    private(set) var uninstallCalls: [(ServiceEngine, String)] = []
    private(set) var toggleCalls: [ServiceEngine] = []
    var setActiveError: Error?
    var uninstallError: Error?
    private var continuation: AsyncStream<[ServiceEngineSnapshot]>.Continuation?

    init(snapshots: [ServiceEngineSnapshot] = []) { engineSnapshots = snapshots }

    func engineSnapshotStream() -> AsyncStream<[ServiceEngineSnapshot]> {
        AsyncStream { continuation in
            self.continuation = continuation
            continuation.yield(self.engineSnapshots)
        }
    }

    func emit(_ next: [ServiceEngineSnapshot]) {
        engineSnapshots = next
        continuation?.yield(next)
    }

    func install(_ release: ServiceEngineRelease) { installCalls.append(release) }
    func cancelInstall(_ release: ServiceEngineRelease) { cancelCalls.append(release) }
    func setActiveVersion(_ engine: ServiceEngine, version: String) throws {
        setActiveCalls.append((engine, version))
        if let setActiveError { throw setActiveError }
    }

    func uninstall(_ engine: ServiceEngine, version: String) throws {
        uninstallCalls.append((engine, version))
        if let uninstallError { throw uninstallError }
    }

    func toggle(_ engine: ServiceEngine) { toggleCalls.append(engine) }
}

@MainActor
final class FakePHPConfig: PHPExtensionManaging, PHPIniEditing {
    var entries: [PHPExtensionEntry] = []
    var installOutcome = PHPExtensionInstallOutcome(loaded: true, warning: nil)
    var installError: Error?
    var uninstallError: Error?
    private(set) var installCalls: [String] = []
    private(set) var uninstallCalls: [String] = []

    var clientPort = 9003
    var supported: [String: Bool] = [:]
    var enabledFlags: [String: Bool] = [:]
    private(set) var setXdebugCalls: [(Bool, String)] = []

    var iniText = "; ini"
    var template = "; default"
    var saveError: Error?
    private(set) var savedIni: [(String, String)] = []

    func extensions(phpVersion _: String) async -> [PHPExtensionEntry] { entries }

    func installExtension(
        _ id: String,
        phpVersion _: String,
        onProgress: @escaping @Sendable (Double) -> Void
    ) async throws -> PHPExtensionInstallOutcome {
        installCalls.append(id)
        onProgress(1)
        if let installError { throw installError }
        return installOutcome
    }

    func uninstallExtension(_ id: String, phpVersion _: String) async throws {
        uninstallCalls.append(id)
        if let uninstallError { throw uninstallError }
    }

    var xdebugClientPort: Int { clientPort }
    func isXdebugSupported(phpVersion: String) -> Bool { supported[phpVersion] ?? true }
    func isXdebugEnabled(phpVersion: String) -> Bool { enabledFlags[phpVersion] ?? false }
    func setXdebug(_ enabled: Bool, phpVersion: String) async throws {
        setXdebugCalls.append((enabled, phpVersion))
        enabledFlags[phpVersion] = enabled
    }

    var defaultTemplate: String { template }
    func readIni(phpVersion _: String) throws -> String { iniText }
    func saveIni(phpVersion: String, contents: String) async throws {
        if let saveError { throw saveError }
        savedIni.append((phpVersion, contents))
    }
}
