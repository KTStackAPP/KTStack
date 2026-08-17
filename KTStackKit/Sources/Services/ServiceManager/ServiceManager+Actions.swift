import Foundation

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
            perform(kind) { running ? try await svc.stop() : try await svc.start() }
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
            perform(kind) { try await svc.restart() }
        }
    }

    public func startAll() {
        if !server.isRunning { server.start() }
        for kind in [ServiceKind.mysql, .postgres, .redis, .mongodb, .mailpit] {
            guard let svc = services[kind], svc.isInstalled, activeInstallKey(kind) == nil else { continue }
            perform(kind) { try await svc.start() }
        }
    }

    public func stopAll() {
        if server.isRunning { server.stop() }
        for kind in [ServiceKind.mysql, .postgres, .redis, .mongodb, .mailpit] {
            guard let svc = services[kind], activeInstallKey(kind) == nil else { continue }
            perform(kind) { try await svc.stop() }
        }
    }

    public func restartAll() {
        server.restart()
        for kind in [ServiceKind.mysql, .postgres, .redis, .mongodb, .mailpit] {
            guard let svc = services[kind], svc.isInstalled, activeInstallKey(kind) == nil else { continue }
            perform(kind) { try await svc.restart() }
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
