import Foundation
import KTPlatformContracts
import KTStackCore

extension CATrustService: CATrustProviding {
    public var caTrustState: CATrustState {
        CATrustState(exists: status != .notInstalled, trusted: isTrusted)
    }

    public func caTrustStates() -> AsyncStream<CATrustState> {
        snapshotStream { self.caTrustState }
    }

    public func refreshTrust() async {
        await refreshAsync()
    }
}
