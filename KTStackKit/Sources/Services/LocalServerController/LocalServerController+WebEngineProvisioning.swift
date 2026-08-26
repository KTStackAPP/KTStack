import Foundation
import KTPlatformContracts
import KTStackCore

extension LocalServerController: WebEngineProvisioning {
    public var webEngineState: WebEngineState {
        WebEngineState(
            apacheVersion: WebEngineCatalog.apacheVersion,
            installed: apacheInstalled,
            installing: apacheInstalling,
            error: apacheInstallError
        )
    }

    public func webEngineStates() -> AsyncStream<WebEngineState> {
        snapshotStream { self.webEngineState }
    }
}
