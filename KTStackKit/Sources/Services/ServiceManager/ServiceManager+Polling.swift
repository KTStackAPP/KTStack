import Foundation

extension ServiceManager {
    public func startPolling(interval: TimeInterval = 0.9) {
        guard pollTask == nil else { return }
        pollTask = Task { [weak self] in
            while !Task.isCancelled {
                await self?.refresh()
                try? await Task.sleep(nanoseconds: UInt64(interval * 1_000_000_000))
            }
        }
    }

    public func stopPolling() {
        pollTask?.cancel(); pollTask = nil
    }

    func refresh() async {
        server.refreshStatus()
        var next: [ServiceSnapshot] = []
        for kind in Self.order {
            switch kind {
            case .nginx: next.append(webSnapshot(kind, status: server.nginxStatus, detail: server.isRunning ? ":80/:443" : "off"))
            case .phpFpm: next.append(webSnapshot(kind, status: server.phpStatus, detail: phpDetail()))
            default: await next.append(independentSnapshot(kind))
            }
        }

        let metrics = await metricsSampler.sample()
        for index in next.indices where next[index].status == .running {
            next[index].cpuPercent = metrics[next[index].kind]?.cpuPercent
            next[index].memoryBytes = metrics[next[index].kind]?.memoryBytes
        }

        if next != snapshots { snapshots = next }
    }

    func independentSnapshot(_ kind: ServiceKind) async -> ServiceSnapshot {
        guard let svc = services[kind] else {
            return ServiceSnapshot(kind: kind, status: .stopped, detail: "", isInstalled: false)
        }
        guard svc.isInstalled else {
            let key = activeInstallKey(kind)
            let fraction = key.flatMap { downloadFraction[$0] }
            let installing = fraction != nil
            return ServiceSnapshot(
                kind: kind, status: .stopped,
                detail: installing ? "Installing…" : "Not installed",
                isInstalled: false, isBusy: busy.contains(kind),
                errorMessage: installErrorMessage(kind),
                installable: catalog.availableRelease(kind) != nil,
                downloadFraction: fraction
            )
        }

        if kind == .dnsmasq {
            let status = await svc.probe()
            return ServiceSnapshot(
                kind: kind,
                status: status,
                detail: svc.detail,
                isInstalled: true,
                isBusy: busy.contains(kind)
            )
        }

        let status: ServiceStatus
        if !agents.isLoaded(kind.launchdLabel) {
            restart.reset(kind)
            status = .stopped
        } else {
            let healthy = await svc.probe() == .running
            status = restart.record(kind, healthy: healthy).status
        }
        return ServiceSnapshot(
            kind: kind,
            status: status,
            detail: svc.detail,
            isInstalled: true,
            isBusy: busy.contains(kind),
            errorMessage: status == .error ? lastErrorMessage(kind) : nil
        )
    }
}
