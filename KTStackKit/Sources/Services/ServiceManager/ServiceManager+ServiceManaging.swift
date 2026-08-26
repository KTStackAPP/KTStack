import Foundation
import KTPlatformContracts
import KTStackCore

extension ServiceManager: ServiceManaging {
    public var serviceStates: [ServiceState] {
        snapshots.map(ServiceState.init(snapshot:))
    }

    public func serviceStateStream() -> AsyncStream<[ServiceState]> {
        snapshotStream { self.serviceStates }
    }

    public func toggle(_ id: ServiceID) {
        toggle(id.serviceKind)
    }

    public func restart(_ id: ServiceID) {
        restart(id.serviceKind)
    }

    public func install(_ id: ServiceID) {
        install(id.serviceKind)
    }

    public func cancelInstall(_ id: ServiceID) {
        cancelInstall(id.serviceKind)
    }

    public func resetData(_ id: ServiceID) {
        resetData(id.serviceKind)
    }
}

extension ServiceID {
    var serviceKind: ServiceKind {
        switch self {
        case .nginx: .nginx
        case .phpFpm: .phpFpm
        case .dnsmasq: .dnsmasq
        case .mysql: .mysql
        case .postgres: .postgres
        case .redis: .redis
        case .mongodb: .mongodb
        case .mailpit: .mailpit
        }
    }
}

extension ServiceState {
    init(snapshot: ServiceSnapshot) {
        self.init(
            id: ServiceID(rawValue: snapshot.kind.rawValue) ?? .nginx,
            displayName: snapshot.displayName,
            symbolName: snapshot.symbolName,
            health: ServiceHealth(snapshot.status),
            detail: snapshot.detail,
            isInstalled: snapshot.isInstalled,
            isBusy: snapshot.isBusy,
            errorMessage: snapshot.errorMessage,
            installable: snapshot.installable,
            downloadFraction: snapshot.downloadFraction,
            metricsText: snapshot.metricsText
        )
    }
}

extension ServiceHealth {
    init(_ status: ServiceStatus) {
        switch status {
        case .running: self = .running
        case .stopped: self = .stopped
        case .starting: self = .starting
        case .stopping: self = .stopping
        case .warning: self = .warning
        case .error: self = .error
        case .info:
            // .info chỉ dùng cho banner, không bao giờ vào snapshots.
            assertionFailure("ServiceStatus.info không được xuất hiện trong snapshots")
            self = .stopped
        }
    }
}
