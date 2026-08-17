import Foundation

extension LocalServerController {
    public func toggle() {
        isRunning ? stop() : start()
    }

    public func start() {
        guard !isBusy, !isRunning else { return }
        isBusy = true; lastError = nil
        nginxStatus = .starting; phpStatus = .starting
        ensureSeed()
        let sites = registry.sites
        let port = httpPort
        Task.detached(priority: .userInitiated) { [stager, self] in
            do {
                LogRotator().rotateOversized(in: paths)
                purgeLegacyNodeAgents()
                try stager.stageIfNeeded()
                await ensureDefaultPHPInstalled(sites: sites)
                let missing = try await applyConfiguration(sites: sites, port: port, startNginx: true)
                await finish(missing: missing, error: nil)
            } catch {
                ServiceDiagnostics(paths: paths).log(.error, "server start failed: \(error.localizedDescription)")
                pools.stopAll(); backends.stopAll(); nginx.stop()
                await finish(missing: [], error: error.localizedDescription)
            }
        }
    }

    public func stop() {
        guard !isBusy else { return }
        isBusy = true; nginxStatus = .stopping; phpStatus = .stopping
        Task.detached(priority: .userInitiated) { [nginx, backends, pools, self] in
            nginx.stop()
            backends.stopAll()
            pools.stopAll()
            await MainActor.run {
                self.nginxStatus = .stopped; self.phpStatus = .stopped; self.isBusy = false
                self.watcher.stop()
            }
        }
    }

    public func restart() {
        guard !isBusy else { return }
        isBusy = true; lastError = nil
        nginxStatus = .starting; phpStatus = .starting
        ensureSeed()
        let sites = registry.sites
        let port = httpPort
        Task.detached(priority: .userInitiated) { [self] in
            nginx.stop(); backends.stopAll(); pools.stopAll()
            do {
                try stager.stageIfNeeded()
                await ensureDefaultPHPInstalled(sites: sites)
                let missing = try await applyConfiguration(sites: sites, port: port, startNginx: true)
                await finish(missing: missing, error: nil)
            } catch {
                pools.stopAll(); backends.stopAll(); nginx.stop()
                await finish(missing: [], error: error.localizedDescription)
            }
        }
    }

    public func shutdownForQuit() {
        watcher.stop()
        agents.bootoutAll()
    }

    public func toggleNginx() {
        isRunning ? stopNginx() : startNginx()
    }

    public func togglePHP() {
        phpRunning ? stopPHP() : startPHP()
    }

    public func startNginx() {
        guard !isBusy, !isRunning else { return }
        isBusy = true; lastError = nil; nginxStatus = .starting
        ensureSeed()
        let sites = registry.sites
        let port = httpPort
        Task.detached(priority: .userInitiated) { [self] in
            do {
                try stager.stageIfNeeded()
                _ = try generator.generate(sites: sites, port: port)
                await backends.reconcile(sites: sites)
                switch preflight.firstConflict(in: frontPorts(for: sites, httpPort: port)) {
                case .available: break
                case let .inUse(_, message), let .blocked(message):
                    throw NSError(domain: "KTStack", code: 2, userInfo: [NSLocalizedDescriptionKey: message])
                }
                try nginx.start()
                try await Self.waitForListening(frontPorts(for: sites, httpPort: port))
                await finish(missing: [], error: nil)
            } catch {
                ServiceDiagnostics(paths: paths).log(.error, "nginx start failed: \(error.localizedDescription)")
                backends.stopAll(); nginx.stop()
                await finish(missing: [], error: error.localizedDescription)
            }
        }
    }

    public func stopNginx() {
        guard !isBusy else { return }
        isBusy = true; nginxStatus = .stopping
        Task.detached(priority: .userInitiated) { [nginx, backends, self] in
            nginx.stop()
            backends.stopAll()
            await MainActor.run { self.isBusy = false; self.recomputeStatus() }
        }
    }

    public func startPHP() {
        guard !isBusy, !phpRunning else { return }
        isBusy = true; lastError = nil; phpStatus = .starting
        ensureSeed()
        let sites = registry.sites
        Task.detached(priority: .userInitiated) { [self] in
            do {
                try stager.stageIfNeeded()
                _ = try pools.reconcile(required: generator.poolVersions(for: sites))
                for version in pools.activeVersions {
                    try await Self.waitForSocket(pools.socket(for: version))
                }
                let installedPHP = Set(BundledPHP.availableVersions(php: paths.phpRuntimesRoot))
                let missing = SiteConfigGenerator.requiredVersions(for: sites)
                    .subtracting(installedPHP).sorted()
                await finish(missing: missing, error: nil)
            } catch {
                ServiceDiagnostics(paths: paths).log(.error, "PHP-FPM start failed: \(error.localizedDescription)")
                pools.stopAll()
                await finish(missing: [], error: error.localizedDescription)
            }
        }
    }

    public func stopPHP() {
        guard !isBusy else { return }
        isBusy = true; phpStatus = .stopping
        Task.detached(priority: .userInitiated) { [pools, self] in
            pools.stopAll()
            await MainActor.run { self.isBusy = false; self.recomputeStatus() }
        }
    }

    public func restartNginx() {
        guard !isBusy else { return }
        isBusy = true; lastError = nil; nginxStatus = .starting
        ensureSeed()
        let sites = registry.sites
        let port = httpPort
        Task.detached(priority: .userInitiated) { [self] in
            nginx.stop()
            do {
                try stager.stageIfNeeded()
                _ = try generator.generate(sites: sites, port: port)
                await backends.reconcile(sites: sites)
                switch preflight.firstConflict(in: frontPorts(for: sites, httpPort: port)) {
                case .available: break
                case let .inUse(_, message), let .blocked(message):
                    throw NSError(domain: "KTStack", code: 2, userInfo: [NSLocalizedDescriptionKey: message])
                }
                try nginx.start()
                try await Self.waitForListening(frontPorts(for: sites, httpPort: port))
                await finish(missing: [], error: nil)
            } catch {
                ServiceDiagnostics(paths: paths).log(.error, "nginx start failed: \(error.localizedDescription)")
                backends.stopAll(); nginx.stop()
                await finish(missing: [], error: error.localizedDescription)
            }
        }
    }

    public func restartPHP() {
        guard !isBusy else { return }
        isBusy = true; lastError = nil; phpStatus = .starting
        ensureSeed()
        let sites = registry.sites
        Task.detached(priority: .userInitiated) { [self] in
            pools.stopAll()
            do {
                try stager.stageIfNeeded()
                _ = try pools.reconcile(required: generator.poolVersions(for: sites))
                for version in pools.activeVersions {
                    try await Self.waitForSocket(pools.socket(for: version))
                }
                await finish(missing: [], error: nil)
            } catch {
                ServiceDiagnostics(paths: paths).log(.error, "PHP-FPM start failed: \(error.localizedDescription)")
                pools.stopAll()
                await finish(missing: [], error: error.localizedDescription)
            }
        }
    }

    nonisolated func purgeLegacyNodeAgents() {
        let legacyPrefix = "com.ktstack.node."
        let labels = agents.loadedLabels(withPrefix: legacyPrefix)
        agents.bootout(matchingPrefix: legacyPrefix)
        for label in labels {
            try? FileManager.default.removeItem(at: paths.launchAgentPlist(label))
        }
    }
}
