import Foundation
import KTPlatformContracts

extension ServiceManager: DatabaseEngineManaging {
    public func isRunning(_ engine: DatabaseEngine) -> Bool {
        // DatabaseEngine.mysql đại diện cả họ 3306: MySQL hoặc MariaDB đang chạy đều tính.
        let kinds: [ServiceKind] = engine == .mysql ? [.mysql, .mariadb] : [engine.serviceKind]
        return snapshots.contains { kinds.contains($0.kind) && $0.status == .running }
    }

    public func install(_ engine: DatabaseEngine) { install(engine.serviceKind) }

    public func toggle(_ engine: DatabaseEngine) { toggle(engine.serviceKind) }
}
