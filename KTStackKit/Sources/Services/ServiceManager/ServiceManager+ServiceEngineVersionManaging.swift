import Foundation
import KTPlatformContracts

extension ServiceManager: ServiceEngineVersionManaging {
    public var engineSnapshots: [ServiceEngineSnapshot] {
        ServiceEngine.allCases.map { engine in
            let kind = engine.serviceKind
            let snap = snapshots.first { $0.kind == kind }
            let available = availableReleases(kind).map { ServiceEngineRelease(engine: engine, version: $0.version) }
            var fractions: [String: Double] = [:]
            for release in availableReleases(kind) {
                if let progress = installProgress(for: release) { fractions[release.id] = progress }
            }
            return ServiceEngineSnapshot(
                engine: engine,
                active: activeVersion(kind),
                installed: installedVersions(kind),
                available: available,
                isRunning: snap?.status == .running,
                isBusy: snap?.isBusy ?? false,
                installInFlight: isInstallInFlight(kind),
                downloadFraction: fractions
            )
        }
    }

    public func engineSnapshotStream() -> AsyncStream<[ServiceEngineSnapshot]> {
        snapshotStream { self.engineSnapshots }
    }

    public func install(_ release: ServiceEngineRelease) {
        let kind = release.engine.serviceKind
        guard let real = availableReleases(kind).first(where: { $0.version == release.version }) else { return }
        install(real)
    }

    public func cancelInstall(_ release: ServiceEngineRelease) {
        let kind = release.engine.serviceKind
        if let real = availableReleases(kind).first(where: { $0.version == release.version }) {
            cancelInstall(real)
        } else {
            cancelInstall(kind)
        }
    }

    public func setActiveVersion(_ engine: ServiceEngine, version: String) throws {
        try setActiveVersion(engine.serviceKind, version: version)
    }

    public func uninstall(_ engine: ServiceEngine, version: String) throws {
        try uninstall(kind: engine.serviceKind, version: version)
    }

    public func toggle(_ engine: ServiceEngine) {
        toggle(engine.serviceKind)
    }
}

extension ServiceEngine {
    var serviceKind: ServiceKind {
        switch self {
        case .mysql: .mysql
        case .postgres: .postgres
        case .redis: .redis
        case .mongodb: .mongodb
        }
    }
}
