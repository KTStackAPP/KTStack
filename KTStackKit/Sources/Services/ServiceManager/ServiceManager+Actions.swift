import Foundation
import KTStackCore

extension ServiceManager {
    public func toggle(_ kind: ServiceKind) {
        let running = snapshot(kind)?.status == .running
        switch kind {
        case .nginx:
            server.toggleNginx()
        case .phpFpm:
            server.togglePHP()
        default:
            guard let svc = services[kind] else { return }
            if running {
                perform(kind) { try await svc.stop() }
            } else {
                run3306Aware(kind, svc) { try await svc.start() }
            }
        }
    }

    // Sibling họ 3306 đang chạy hay không (chỉ mysql/mariadb có sibling).
    private func runningSibling3306(_ kind: ServiceKind) -> (other: ServiceKind, svc: ManagedService)? {
        guard let other = SQLFamily.other(kind),
              snapshot(other)?.status == .running, let otherSvc = services[other] else { return nil }
        return (other, otherSvc)
    }

    // MySQL và MariaDB dùng chung 3306: nếu sibling đang chạy thì bootout nó trước rồi start engine này,
    // không thì chạy action bình thường. Chặn mọi lối start/restart nạp hai job 3306 cùng lúc.
    private func run3306Aware(_ kind: ServiceKind, _ svc: ManagedService,
                              action: @escaping @Sendable () async throws -> Void) {
        if let (other, otherSvc) = runningSibling3306(kind) {
            handoff3306(start: kind, startSvc: svc, stop: other, stopSvc: otherSvc)
        } else {
            perform(kind) { try await action() }
        }
    }

    // Bootout engine 3306 đang chạy rồi mới bootstrap engine mới: không có lúc nào hai job cùng loaded.
    private func handoff3306(
        start: ServiceKind, startSvc: ManagedService,
        stop: ServiceKind, stopSvc: ManagedService
    ) {
        guard !busy.contains(start), !busy.contains(stop) else { return }
        busy.insert(start); busy.insert(stop)
        restart.reset(start); restart.reset(stop)
        setSnapshotBusy(start, true); setSnapshotBusy(stop, true)
        Task { [weak self] in
            var startMessage: String?
            do {
                try await stopSvc.stop()
                try await startSvc.start()
            } catch {
                startMessage = error.localizedDescription
            }
            await self?.refresh()
            await MainActor.run {
                guard let self else { return }
                self.busy.remove(start); self.busy.remove(stop)
                self.setSnapshotBusy(start, false, errorMessage: startMessage)
                self.setSnapshotBusy(stop, false)
            }
        }
    }

    public func restart(_ kind: ServiceKind) {
        switch kind {
        case .nginx:
            server.restartNginx()
        case .phpFpm:
            server.restartPHP()
        default:
            guard let svc = services[kind] else { return }
            run3306Aware(kind, svc) { try await svc.restart() }
        }
    }

    public func startAll() {
        if !server.isRunning { server.start() }
        let mysqlInstalled = services[.mysql]?.isInstalled == true
        for kind in Self.onDemandKinds {
            // Cùng port 3306: nếu MySQL đã cài thì bỏ qua MariaDB, tránh start hai engine tranh cổng.
            if kind == .mariadb, mysqlInstalled { continue }
            guard let svc = services[kind], svc.isInstalled, activeInstallKey(kind) == nil else { continue }
            run3306Aware(kind, svc) { try await svc.start() }
        }
    }

    public func stopAll() {
        if server.isRunning { server.stop() }
        for kind in Self.onDemandKinds {
            guard let svc = services[kind], activeInstallKey(kind) == nil else { continue }
            perform(kind) { try await svc.stop() }
        }
    }

    public func restartAll() {
        server.restart()
        let mysqlInstalled = services[.mysql]?.isInstalled == true
        for kind in Self.onDemandKinds {
            if kind == .mariadb, mysqlInstalled { continue }
            guard let svc = services[kind], svc.isInstalled, activeInstallKey(kind) == nil else { continue }
            run3306Aware(kind, svc) { try await svc.restart() }
        }
    }

    public func resetData(_ kind: ServiceKind) {
        guard let svc = services[kind] else { return }
        let paths = paths
        let version = Self.dbCacheKinds.contains(kind) ? versionStore.activeVersion(kind) : nil
        perform(kind) {
            try? await svc.stop()
            Self.removeServiceData(kind, version: version, paths: paths)
        }
    }

    public nonisolated static func removeServiceData(_ kind: ServiceKind, version: String?, paths: AppSupportPaths) {
        let target: URL
        if let v = version, dbCacheKinds.contains(kind) {
            target = paths.serviceData(kind.rawValue, version: v)
        } else {
            target = paths.serviceData(kind.rawValue)
        }
        try? FileManager.default.removeItem(at: target)
    }

    func perform(_ kind: ServiceKind, _ action: @escaping @Sendable () async throws -> Void) {
        guard !busy.contains(kind) else { return }
        busy.insert(kind)
        restart.reset(kind)

        setSnapshotBusy(kind, true)
        Task { [weak self] in
            var message: String?
            do { try await action() } catch { message = error.localizedDescription }
            // Refresh status BEFORE clearing busy: otherwise the row briefly shows the toggle at
            // its stale (pre-op) state, then jumps, which reads as a stutter. While still busy the
            // toggle stays dimmed, so it slides straight to the settled state when busy clears.
            await self?.refresh()
            await MainActor.run {
                guard let self else { return }
                self.busy.remove(kind)
                self.setSnapshotBusy(kind, false, errorMessage: message)
            }
        }
    }
}
