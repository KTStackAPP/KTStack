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
            for await next in engines.engineSnapshotStream() { self?.snapshots = next }
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

    func snapshot(_ engine: ServiceEngine) -> ServiceEngineSnapshot? {
        snapshots.first { $0.engine == engine }
    }

    func install(_ release: ServiceEngineRelease) { engines.install(release) }

    func cancelInstall(_ release: ServiceEngineRelease) { engines.cancelInstall(release) }

    func toggle(_ engine: ServiceEngine) { engines.toggle(engine) }

    func setActive(_ engine: ServiceEngine, version: String) -> Result<Void, Error> {
        Result { try engines.setActiveVersion(engine, version: version) }
    }

    func uninstall(_ engine: ServiceEngine, version: String) -> Result<Void, Error> {
        Result { try engines.uninstall(engine, version: version) }
    }
}
