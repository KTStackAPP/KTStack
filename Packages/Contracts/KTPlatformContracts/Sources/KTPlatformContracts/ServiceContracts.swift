import Foundation

// rawValue trùng ServiceKind.rawValue: banner id "error-<raw>" và runtime dir dùng nó. Frozen.
public enum ServiceID: String, Sendable, CaseIterable, Hashable {
    case nginx, phpFpm, dnsmasq, mysql, mariadb, postgres, redis, memcached, mongodb, mailpit

    public var engine: ServiceEngine? {
        switch self {
        case .mysql: .mysql
        case .mariadb: .mariadb
        case .postgres: .postgres
        case .redis: .redis
        case .memcached: .memcached
        case .mongodb: .mongodb
        default: nil
        }
    }
}

public enum ServiceHealth: String, Sendable {
    case running, stopped, starting, stopping, warning, error

    public var label: String {
        switch self {
        case .running: "Running"
        case .stopped: "Stopped"
        case .starting: "Starting"
        case .stopping: "Stopping"
        case .warning: "Warning"
        case .error: "Error"
        }
    }
}

public struct ServiceState: Sendable, Equatable, Identifiable {
    public let id: ServiceID
    public let displayName: String
    public let symbolName: String
    public let health: ServiceHealth
    public let detail: String
    public let isInstalled: Bool
    public let isBusy: Bool
    public let errorMessage: String?
    public let installable: Bool
    public let downloadFraction: Double?
    public let metricsText: String?

    public init(
        id: ServiceID,
        displayName: String,
        symbolName: String,
        health: ServiceHealth,
        detail: String,
        isInstalled: Bool,
        isBusy: Bool,
        errorMessage: String?,
        installable: Bool,
        downloadFraction: Double?,
        metricsText: String?
    ) {
        self.id = id
        self.displayName = displayName
        self.symbolName = symbolName
        self.health = health
        self.detail = detail
        self.isInstalled = isInstalled
        self.isBusy = isBusy
        self.errorMessage = errorMessage
        self.installable = installable
        self.downloadFraction = downloadFraction
        self.metricsText = metricsText
    }
}

public protocol ServiceManaging: AnyObject {
    @MainActor var serviceStates: [ServiceState] { get }
    @MainActor func serviceStateStream() -> AsyncStream<[ServiceState]>
    @MainActor func toggle(_ id: ServiceID)
    @MainActor func restart(_ id: ServiceID)
    @MainActor func startAll()
    @MainActor func restartAll()
    @MainActor func install(_ id: ServiceID)
    @MainActor func cancelInstall(_ id: ServiceID)
    @MainActor func resetData(_ id: ServiceID)
}
