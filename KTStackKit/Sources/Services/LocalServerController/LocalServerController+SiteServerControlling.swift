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

    public func probeNode(port: Int) async -> Bool {
        await HealthChecker().check(.tcp(port: port)) == .running
    }
}
