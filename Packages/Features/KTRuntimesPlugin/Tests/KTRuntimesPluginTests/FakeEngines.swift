import Foundation
import KTPlatformContracts

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
    var retiredDataError: Error?
    var footprints: [String: ServiceEngineDataFootprint] = [:]
    var retired: [ServiceEngineRetiredData] = []
    private(set) var restoreCalls: [ServiceEngineRetiredData] = []
    private(set) var trashCalls: [ServiceEngineRetiredData] = []
    private var continuation: AsyncStream<[ServiceEngineSnapshot]>.Continuation?

    init(snapshots: [ServiceEngineSnapshot] = []) {
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

    func install(_ release: ServiceEngineRelease) {
        installCalls.append(release)
    }

    func cancelInstall(_ release: ServiceEngineRelease) {
        cancelCalls.append(release)
    }

    func setActiveVersion(_ engine: ServiceEngine, version: String) throws {
        setActiveCalls.append((engine, version))
        if let setActiveError { throw setActiveError }
    }

    func dataFootprint(_ engine: ServiceEngine, version: String) async -> ServiceEngineDataFootprint? {
        footprints["\(engine.rawValue)-\(version)"]
    }

    func uninstall(_ engine: ServiceEngine, version: String) async throws -> String? {
        uninstallCalls.append((engine, version))
        if let uninstallError { throw uninstallError }
        return footprints["\(engine.rawValue)-\(version)"]?.path
    }

    func retiredData(_ engine: ServiceEngine) async -> [ServiceEngineRetiredData] {
        retired.filter { $0.engine == engine }
    }

    func restoreRetiredData(_ item: ServiceEngineRetiredData) async throws {
        restoreCalls.append(item)
        if let retiredDataError { throw retiredDataError }
        retired.removeAll { $0 == item }
    }

    func trashRetiredData(_ item: ServiceEngineRetiredData) async throws {
        trashCalls.append(item)
        if let retiredDataError { throw retiredDataError }
        retired.removeAll { $0 == item }
    }

    func toggle(_ engine: ServiceEngine) {
        toggleCalls.append(engine)
    }
}
