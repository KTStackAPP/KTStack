import Foundation
import KTStackCore

extension ServiceManager {
    public func ensureSQLFamilyRunning() async throws {
        if await UpstreamProbe().probe(host: "127.0.0.1", port: 3306) == .running { return }
        guard let kind = SQLFamily.preferredKind(catalog: catalog), let svc = services[kind] else {
            throw ServiceNotInstalled(.mysql)
        }
        restart.reset(kind)
        setSnapshotBusy(kind, true)
        defer { setSnapshotBusy(kind, false) }
        try await svc.start()
        await refresh()
    }
}
