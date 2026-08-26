import Foundation
import KTPlatformContracts

func makeState(
    _ id: ServiceID,
    health: ServiceHealth = .stopped,
    detail: String = "",
    isInstalled: Bool = true,
    isBusy: Bool = false,
    errorMessage: String? = nil,
    installable: Bool = false,
    downloadFraction: Double? = nil,
    metricsText: String? = nil
) -> ServiceState {
    ServiceState(
        id: id,
        displayName: id.rawValue,
        symbolName: "circle",
        health: health,
        detail: detail,
        isInstalled: isInstalled,
        isBusy: isBusy,
        errorMessage: errorMessage,
        installable: installable,
        downloadFraction: downloadFraction,
        metricsText: metricsText
    )
}

@MainActor
final class FakeServiceManaging: ServiceManaging {
    var serviceStates: [ServiceState]
    private(set) var toggleCalls: [ServiceID] = []
    private(set) var restartCalls: [ServiceID] = []
    private(set) var installCalls: [ServiceID] = []
    private(set) var cancelInstallCalls: [ServiceID] = []
    private(set) var resetDataCalls: [ServiceID] = []
    private(set) var startAllCalls = 0
    private(set) var restartAllCalls = 0
    private var continuation: AsyncStream<[ServiceState]>.Continuation?

    nonisolated init(states: [ServiceState] = []) {
        serviceStates = states
    }

    func serviceStateStream() -> AsyncStream<[ServiceState]> {
        AsyncStream { continuation in
            self.continuation = continuation
            continuation.yield(self.serviceStates)
        }
    }

    func emit(_ next: [ServiceState]) {
        serviceStates = next
        continuation?.yield(next)
    }

    func toggle(_ id: ServiceID) { toggleCalls.append(id) }
    func restart(_ id: ServiceID) { restartCalls.append(id) }
    func startAll() { startAllCalls += 1 }
    func restartAll() { restartAllCalls += 1 }
    func install(_ id: ServiceID) { installCalls.append(id) }
    func cancelInstall(_ id: ServiceID) { cancelInstallCalls.append(id) }
    func resetData(_ id: ServiceID) { resetDataCalls.append(id) }
}

@MainActor
final class FakeEngineVersionManaging: ServiceEngineVersionManaging {
    var engineSnapshots: [ServiceEngineSnapshot]
    var setActiveShouldThrow = false
    private(set) var setActiveCalls: [(ServiceEngine, String)] = []
    private var continuation: AsyncStream<[ServiceEngineSnapshot]>.Continuation?

    struct SetActiveError: Error {}

    nonisolated init(snapshots: [ServiceEngineSnapshot] = []) {
        engineSnapshots = snapshots
    }

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

    func install(_: ServiceEngineRelease) {}
    func cancelInstall(_: ServiceEngineRelease) {}
    func setActiveVersion(_ engine: ServiceEngine, version: String) throws {
        setActiveCalls.append((engine, version))
        if setActiveShouldThrow { throw SetActiveError() }
    }

    func uninstall(_: ServiceEngine, version _: String) throws {}
    func toggle(_: ServiceEngine) {}
}

@MainActor
final class FakeDNSResolver: DNSResolverManaging {
    var dnsState: DNSResolverState
    private(set) var enableCalls = 0
    private(set) var resetCalls = 0
    private(set) var refreshCalls = 0
    private var continuation: AsyncStream<DNSResolverState>.Continuation?

    nonisolated init(state: DNSResolverState = DNSResolverState(
        status: .enabled, isBusy: false, lastError: nil, usesHelper: false, helperNeedsApproval: false
    )) {
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

    private(set) var disableCalls = 0
    func enable() { enableCalls += 1 }
    func reset() { resetCalls += 1 }
    func refresh() { refreshCalls += 1 }
    func disable() { disableCalls += 1 }
}

@MainActor
final class FakeCATrust: CATrustProviding {
    var caTrustState: CATrustState
    private(set) var refreshCalls = 0
    private var continuation: AsyncStream<CATrustState>.Continuation?

    nonisolated init(state: CATrustState = CATrustState(exists: true, trusted: true)) {
        caTrustState = state
    }

    func caTrustStates() -> AsyncStream<CATrustState> {
        AsyncStream { continuation in
            self.continuation = continuation
            continuation.yield(self.caTrustState)
        }
    }

    func emit(_ next: CATrustState) {
        caTrustState = next
        continuation?.yield(next)
    }

    func refreshTrust() async { refreshCalls += 1 }
}

final class FakeNginxInclude: NginxIncludeEditing, @unchecked Sendable {
    var defaultInclude: String
    var stored: String
    var readShouldThrow = false
    var saveError: NginxIncludeSaveError?
    private(set) var savedContents: [String] = []

    struct ReadError: Error {}

    init(defaultInclude: String = "DEFAULT", stored: String = "STORED") {
        self.defaultInclude = defaultInclude
        self.stored = stored
    }

    func readInclude() throws -> String {
        if readShouldThrow { throw ReadError() }
        return stored
    }

    func saveInclude(_ contents: String) async throws {
        savedContents.append(contents)
        if let saveError { throw saveError }
        stored = contents
    }
}
