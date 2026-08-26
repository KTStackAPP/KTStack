import Foundation
import KTPlatformContracts
import KTStackCore
@testable import KTSitesPlugin

func makeSite(
    id: UUID = UUID(),
    name: String = "example",
    path: String = "/sites/example",
    docroot: String = "/sites/example",
    domain: String = "example.test",
    phpVersion: String = "8.4",
    kind: SiteKind = .php,
    databaseName: String? = nil,
    secure: Bool = true,
    nodePort: Int? = nil,
    nodeCommand: String? = nil,
    engine: SiteServerEngine = .nginx,
    backendPort: Int? = 9001,
    proxyTarget: String? = nil
) -> SiteSummary {
    SiteSummary(
        id: id, name: name, path: path, docroot: docroot, domain: domain, phpVersion: phpVersion,
        kind: kind, databaseName: databaseName, secure: secure, nodePort: nodePort,
        nodeCommand: nodeCommand, engine: engine, backendPort: backendPort, proxyTarget: proxyTarget
    )
}

@MainActor
final class FakeSiteCatalog: SiteCatalogManaging {
    var catalog: SiteCatalogState
    var editDomainShouldThrow: Error?
    private(set) var setPHPVersionCalls: [(UUID, String)] = []
    private(set) var setSecureCalls: [(UUID, Bool)] = []
    private(set) var setNodePortCalls: [(UUID, Int?)] = []
    private(set) var setEngineCalls: [(UUID, SiteServerEngine)] = []
    private(set) var setProxyTargetCalls: [(UUID, String)] = []
    var setProxyTargetShouldThrow: Error?
    private(set) var setAliasesCalls: [(UUID, [String])] = []
    var setAliasesShouldThrow: Error?
    var validateAliasesShouldThrow: Error?
    private(set) var setEnvVarsCalls: [(UUID, [String: String])] = []
    var setEnvVarsShouldThrow: Error?
    private(set) var saveFrontDirectivesCalls: [(UUID, String)] = []
    var saveFrontDirectivesShouldThrow: Error?
    private var continuation: AsyncStream<SiteCatalogState>.Continuation?

    nonisolated init(catalog: SiteCatalogState) {
        self.catalog = catalog
    }

    func catalogStream() -> AsyncStream<SiteCatalogState> {
        AsyncStream { continuation in
            self.continuation = continuation
            continuation.yield(self.catalog)
        }
    }

    func emit(_ next: SiteCatalogState) {
        catalog = next
        continuation?.yield(next)
    }

    func setPHPVersion(_ id: UUID, _ version: String) { setPHPVersionCalls.append((id, version)) }

    func editDomain(_ id: UUID, _ domain: String) throws {
        if let editDomainShouldThrow { throw editDomainShouldThrow }
        _ = (id, domain)
    }

    func validateDomain(_: String, excluding _: UUID?) throws {}
    func setSecure(_ id: UUID, _ secure: Bool) { setSecureCalls.append((id, secure)) }
    func setNodePort(_ id: UUID, _ port: Int?) { setNodePortCalls.append((id, port)) }
    func setEngine(_ id: UUID, _ engine: SiteServerEngine) { setEngineCalls.append((id, engine)) }
    func setProxyTarget(_ id: UUID, _ target: String) throws {
        if let setProxyTargetShouldThrow { throw setProxyTargetShouldThrow }
        setProxyTargetCalls.append((id, target))
    }

    func setAliases(_ id: UUID, _ aliases: [String]) throws {
        if let setAliasesShouldThrow { throw setAliasesShouldThrow }
        setAliasesCalls.append((id, aliases))
    }

    func validateAliases(_: [String], for _: UUID) throws {
        if let validateAliasesShouldThrow { throw validateAliasesShouldThrow }
    }

    func setEnvVars(_ id: UUID, _ env: [String: String]) throws {
        if let setEnvVarsShouldThrow { throw setEnvVarsShouldThrow }
        setEnvVarsCalls.append((id, env))
    }

    func saveFrontDirectives(_ id: UUID, _ text: String) async throws {
        if let saveFrontDirectivesShouldThrow { throw saveFrontDirectivesShouldThrow }
        saveFrontDirectivesCalls.append((id, text))
    }
}

@MainActor
final class FakeSiteServerControl: SiteServerControlling {
    var serverState: SiteServerState
    var nodeProbeResult = true
    private(set) var toggleCalls = 0
    private(set) var probeUpstreamCalls: [(host: String, port: Int)] = []
    private var continuation: AsyncStream<SiteServerState>.Continuation?

    nonisolated init(state: SiteServerState) {
        serverState = state
    }

    func serverStates() -> AsyncStream<SiteServerState> {
        AsyncStream { continuation in
            self.continuation = continuation
            continuation.yield(self.serverState)
        }
    }

    func emit(_ next: SiteServerState) {
        serverState = next
        continuation?.yield(next)
    }

    func toggle() { toggleCalls += 1 }

    nonisolated func probeUpstream(host: String, port: Int) async -> Bool {
        await MainActor.run {
            self.probeUpstreamCalls.append((host, port))
            return self.nodeProbeResult
        }
    }
}

@MainActor
final class FakeWebEngine: WebEngineProvisioning {
    var webEngineState: WebEngineState
    private(set) var installApacheCalls = 0
    private var continuation: AsyncStream<WebEngineState>.Continuation?

    nonisolated init(state: WebEngineState) {
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
final class FakeRuntimeManaging: RuntimeManaging {
    var state: RuntimeState
    private(set) var installCalls: [RuntimeRelease] = []
    private var continuation: AsyncStream<RuntimeState>.Continuation?
    private let endOfLifeLock = NSLock()
    nonisolated(unsafe) private var lockedEndOfLifeVersions: Set<String> = []

    nonisolated var endOfLifeVersions: Set<String> {
        get { endOfLifeLock.withLock { lockedEndOfLifeVersions } }
        set { endOfLifeLock.withLock { lockedEndOfLifeVersions = newValue } }
    }

    nonisolated init(state: RuntimeState) {
        self.state = state
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

    func availableReleases(_: RuntimeLanguage) -> [RuntimeRelease] { [] }
    func install(_ release: RuntimeRelease) { installCalls.append(release) }
    func cancel(_: RuntimeLanguage) {}
    func setGlobalDefault(_: RuntimeLanguage, _: String) {}
    func uninstall(_: RuntimeLanguage, _: String) {}
    nonisolated func isEndOfLife(_: RuntimeLanguage, _ version: String) -> Bool {
        endOfLifeVersions.contains(version)
    }
}

@MainActor
final class FakeSiteSharing: SiteSharing {
    var shareStates: [UUID: SiteShareState]
    private(set) var startShareCalls: [TunnelSiteTarget] = []
    private(set) var stopShareCalls: [UUID] = []
    private var continuation: AsyncStream<[UUID: SiteShareState]>.Continuation?

    nonisolated init(states: [UUID: SiteShareState] = [:]) {
        shareStates = states
    }

    func shareStateStream() -> AsyncStream<[UUID: SiteShareState]> {
        AsyncStream { continuation in
            self.continuation = continuation
            continuation.yield(self.shareStates)
        }
    }

    func emit(_ next: [UUID: SiteShareState]) {
        shareStates = next
        continuation?.yield(next)
    }

    func startShare(_ target: TunnelSiteTarget) { startShareCalls.append(target) }
    func stopShare(siteID: UUID) { stopShareCalls.append(siteID) }
}

@MainActor
final class FakeDNSResolving: DNSResolverManaging {
    var dnsState: DNSResolverState
    private(set) var enableCalls = 0
    private(set) var disableCalls = 0
    private(set) var resetCalls = 0
    private(set) var refreshCalls = 0
    private var continuation: AsyncStream<DNSResolverState>.Continuation?

    nonisolated init(state: DNSResolverState) {
        dnsState = state
    }

    func dnsStates() -> AsyncStream<DNSResolverState> {
        AsyncStream { continuation in
            self.continuation = continuation
            continuation.yield(self.dnsState)
        }
    }

    func emit(_ next: DNSResolverState) {
        dnsState = next
        continuation?.yield(next)
    }

    func enable() { enableCalls += 1 }
    func disable() { disableCalls += 1 }
    func reset() { resetCalls += 1 }
    func refresh() { refreshCalls += 1 }
}

final class FakeSiteProvisioning: SiteProvisioning, @unchecked Sendable {
    var installResult: Result<SiteSummary, Error>?
    var importResult: Result<SiteSummary, Error>?
    var registerResult: Result<SiteSummary, Error>?
    var addProxyResult: Result<SiteSummary, Error>?
    var removeError: Error?
    var scanResult: [ScannedFolder] = []
    struct AddProxyCall { let name: String; let domain: String; let target: String; let https: Bool }
    private(set) var addProxyCalls: [AddProxyCall] = []
    var inspectResult = FolderInspection(docroot: URL(fileURLWithPath: "/tmp"), defaultDomain: "tmp.test", kind: .php)
    private(set) var removeCalls: [(UUID, Bool, Bool)] = []
    private(set) var installEvents: [InstallEvent] = []

    func install(_ request: NewSiteRequest, enableHTTPS _: Bool, emit: @escaping @Sendable (InstallEvent) -> Void) async throws -> SiteSummary {
        emit(InstallEvent(phase: .preparing, message: "preparing"))
        installEvents.append(InstallEvent(phase: .preparing, message: "preparing"))
        guard let installResult else { return makeSite(name: request.name, domain: request.domain) }
        return try installResult.get()
    }

    func importFolder(_ folder: URL, domain: String, phpVersion _: String, createDatabase _: Bool, enableHTTPS _: Bool) async throws -> SiteSummary {
        guard let importResult else { return makeSite(name: folder.lastPathComponent, domain: domain) }
        return try importResult.get()
    }

    func registerFolder(_ folder: URL, phpVersion _: String) throws -> SiteSummary {
        guard let registerResult else { return makeSite(name: folder.lastPathComponent) }
        return try registerResult.get()
    }

    func addProxySite(name: String, domain: String, target: String, enableHTTPS: Bool) async throws -> SiteSummary {
        addProxyCalls.append(AddProxyCall(name: name, domain: domain, target: target, https: enableHTTPS))
        guard let addProxyResult else {
            return makeSite(name: name, domain: domain, kind: .proxy)
        }
        return try addProxyResult.get()
    }

    func remove(_ id: UUID, deleteFolder: Bool, dropDatabase: Bool) async throws {
        removeCalls.append((id, deleteFolder, dropDatabase))
        if let removeError { throw removeError }
    }

    func scan(root _: URL, tld _: String, existingPaths _: [String]) -> [ScannedFolder] { scanResult }
    func inspect(folder _: URL, tld _: String) -> FolderInspection { inspectResult }
}

final class FakeWordPressRestoring: WordPressRestoring, @unchecked Sendable {
    var inspectResult: Result<WordPressBackupKind, Error> = .success(.duplicatorZip)
    var restoreResult: Result<RestoreOutcome, Error> = .success(RestoreOutcome(domain: "example.test", warnings: []))
    private(set) var restoreEvents: [RestoreEvent] = []

    func inspectBackup(_: URL) throws -> WordPressBackupKind {
        try inspectResult.get()
    }

    func restore(_ request: RestoreRequest, into _: UUID, emit: @escaping @Sendable (RestoreEvent) -> Void) async throws -> RestoreOutcome {
        emit(RestoreEvent(phase: .detecting, message: "detecting"))
        restoreEvents.append(RestoreEvent(phase: .detecting, message: "detecting"))
        _ = request
        return try restoreResult.get()
    }
}

final class FakeSiteIDEConfiguring: SiteIDEConfiguring, @unchecked Sendable {
    var result: Result<URL, Error> = .success(URL(fileURLWithPath: "/tmp/.vscode/launch.json"))
    private(set) var calls: [(URL, URL)] = []

    func writeVSCodeDebugConfig(projectRoot: URL, docroot: URL) throws -> URL {
        calls.append((projectRoot, docroot))
        return try result.get()
    }
}
