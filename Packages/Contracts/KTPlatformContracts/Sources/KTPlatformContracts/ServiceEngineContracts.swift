import Foundation

// Contract hẹp cho M10 "Databases & Cache" section (on-demand DB/cache engine). M11 tự định nghĩa
// ServiceManaging cho màn Services; nếu snapshot này khớp thì tái dùng, không thiết kế trước.

public enum ServiceEngine: String, Sendable, CaseIterable, Hashable {
    case mysql, postgres, redis, mongodb
}

public struct ServiceEngineRelease: Sendable, Hashable, Identifiable {
    public let engine: ServiceEngine
    public let version: String

    public init(engine: ServiceEngine, version: String) {
        self.engine = engine
        self.version = version
    }

    // Phải trùng ServiceBinaryRelease.id để downloadFraction map thẳng từ ServiceManager.
    public var id: String { "\(engine.rawValue)-\(version)" }
}

public struct ServiceEngineSnapshot: Sendable, Equatable, Identifiable {
    public let engine: ServiceEngine
    public let active: String?
    public let installed: [String]
    public let available: [ServiceEngineRelease]
    public let isRunning: Bool
    public let isBusy: Bool
    public let installInFlight: Bool
    public let downloadFraction: [String: Double] // key = release.id

    public init(
        engine: ServiceEngine,
        active: String?,
        installed: [String],
        available: [ServiceEngineRelease],
        isRunning: Bool,
        isBusy: Bool,
        installInFlight: Bool,
        downloadFraction: [String: Double]
    ) {
        self.engine = engine
        self.active = active
        self.installed = installed
        self.available = available
        self.isRunning = isRunning
        self.isBusy = isBusy
        self.installInFlight = installInFlight
        self.downloadFraction = downloadFraction
    }

    public var id: String { engine.rawValue }
}

public protocol ServiceEngineVersionManaging: AnyObject {
    @MainActor var engineSnapshots: [ServiceEngineSnapshot] { get }
    @MainActor func engineSnapshotStream() -> AsyncStream<[ServiceEngineSnapshot]>
    @MainActor func install(_ release: ServiceEngineRelease)
    @MainActor func cancelInstall(_ release: ServiceEngineRelease)
    @MainActor func setActiveVersion(_ engine: ServiceEngine, version: String) throws
    @MainActor func uninstall(_ engine: ServiceEngine, version: String) throws
    @MainActor func toggle(_ engine: ServiceEngine)
}
