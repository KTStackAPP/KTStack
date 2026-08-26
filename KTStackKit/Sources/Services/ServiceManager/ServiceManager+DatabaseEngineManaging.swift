import Foundation
import KTPlatformContracts

extension ServiceManager: DatabaseEngineManaging {
    public func isRunning(_ engine: DatabaseEngine) -> Bool {
        snapshots.first { $0.kind == engine.serviceKind }?.status == .running
    }

    public func install(_ engine: DatabaseEngine) { install(engine.serviceKind) }

    public func toggle(_ engine: DatabaseEngine) { toggle(engine.serviceKind) }
}
