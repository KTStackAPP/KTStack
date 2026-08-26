import Foundation
import KTPlatformContracts
import KTStackCore

extension LocalServerController: SiteServerControlling {
    public var serverState: SiteServerState {
        SiteServerState(
            isRunning: isRunning,
            isBusy: isBusy,
            lastError: lastError,
            phpVersions: availableVersions
        )
    }

    public func serverStates() -> AsyncStream<SiteServerState> {
        snapshotStream { self.serverState }
    }

    public func probeUpstream(host: String, port: Int) async -> Bool {
        await HealthChecker().check(.tcpHost(host: host, port: port)) == .running
    }
}
