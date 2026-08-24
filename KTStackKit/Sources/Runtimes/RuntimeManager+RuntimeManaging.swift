import Foundation
import KTPlatformContracts
import KTStackCore

extension RuntimeManager: RuntimeManaging {
    public var state: RuntimeState {
        RuntimeState(
            installed: installed,
            defaults: globalDefaults,
            downloads: downloads.mapValues {
                RuntimeDownloadProgress(version: $0.version, received: $0.received, total: $0.total, error: $0.error)
            }
        )
    }

    public func states() -> AsyncStream<RuntimeState> {
        snapshotStream { self.state }
    }

    public func isEndOfLife(_ lang: RuntimeLanguage, _ version: String) -> Bool {
        lang == .php && BundledPHP.isEndOfLife(version)
    }
}
