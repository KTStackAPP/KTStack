import Foundation
import KTPlatformContracts
import SwiftUI

@MainActor
final class EngineVersionsViewModel: ObservableObject {
    struct Entry: Identifiable {
        let id: String
        let engine: ServiceEngine
        let version: String
        let state: EngineVersionState
        let release: ServiceEngineRelease?
    }

    @Published private(set) var snapshots: [ServiceEngineSnapshot] = []

    private let engines: any ServiceEngineVersionManaging
    private var task: Task<Void, Never>?

    init(engines: any ServiceEngineVersionManaging) {
        self.engines = engines
        snapshots = engines.engineSnapshots
        task = Task { [weak self] in
            for await next in engines.engineSnapshotStream() {
                self?.snapshots = next
            }
        }
    }

    deinit { task?.cancel() }

    var rows: [Entry] {
        var result: [Entry] = []
        for snap in snapshots {
            for version in snap.installed {
                result.append(Entry(
                    id: "\(snap.engine.rawValue)-\(version)",
                    engine: snap.engine,
                    version: version,
                    state: version == snap.active ? .active : .installed,
                    release: nil
                ))
            }
            for release in snap.available {
                result.append(Entry(
                    id: release.id,
                    engine: snap.engine,
                    version: release.version,
                    state: .available,
                    release: release
                ))
            }
        }
        return result
    }

    /// Một engine: installed (active trước) rồi available.
    func rows(for engine: ServiceEngine) -> [Entry] {
        guard let snap = snapshot(engine) else { return [] }
        let installed = snap.installed.sorted { lhs, rhs in
            if lhs == snap.active { return true }
            if rhs == snap.active { return false }
            return lhs.compare(rhs, options: .numeric) == .orderedDescending
        }
        var result = installed.map { version in
            Entry(
                id: "\(engine.rawValue)-\(version)",
                engine: engine,
                version: version,
                state: version == snap.active ? .active : .installed,
                release: nil
            )
        }
        result += snap.available.map {
            Entry(id: $0.id, engine: engine, version: $0.version, state: .available, release: $0)
        }
        return result
    }

    func railSummary(_ engine: ServiceEngine) -> String {
        guard let snap = snapshot(engine), !snap.installed.isEmpty else { return "Not installed" }
        return "\(snap.active ?? snap.installed.first ?? "") active"
    }

    func isRunning(_ engine: ServiceEngine) -> Bool {
        snapshot(engine)?.isRunning ?? false
    }

    // Lý do chặn switch/uninstall version khác; nil = cho phép.
    func switchBlockReason(_ engine: ServiceEngine) -> String? {
        guard let snap = snapshot(engine) else { return nil }
        if snap.isRunning || snap.isBusy { return "Stop \(engine.displayName) \(snap.active ?? "") to switch" }
        if snap.installInFlight { return "Installing…" }
        return nil
    }

    func metaLine(_ entry: Entry) -> String {
        guard let snap = snapshot(entry.engine) else { return "" }
        switch entry.state {
        case .active:
            if snap.isBusy { return snap.isRunning ? "Stopping…" : "Starting…" }
            return snap.isRunning ? "Running · data stored per version" : "Stopped · data stored per version"
        case .installed:
            return switchBlockReason(entry.engine) ?? "Installed, not active"
        case .available:
            return ""
        }
    }

    func snapshot(_ engine: ServiceEngine) -> ServiceEngineSnapshot? {
        snapshots.first { $0.engine == engine }
    }

    func install(_ release: ServiceEngineRelease) {
        engines.install(release)
    }

    func cancelInstall(_ release: ServiceEngineRelease) {
        engines.cancelInstall(release)
    }

    func toggle(_ engine: ServiceEngine) {
        engines.toggle(engine)
    }

    func setActive(_ engine: ServiceEngine, version: String) -> Result<Void, Error> {
        Result { try engines.setActiveVersion(engine, version: version) }
    }

    func uninstall(_ engine: ServiceEngine, version: String) -> Result<Void, Error> {
        Result { try engines.uninstall(engine, version: version) }
    }
}
