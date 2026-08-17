import Foundation

extension LocalServerController {
    public func setSiteSecure(_ site: Site, _ secure: Bool) {
        guard !isBusy else { return }
        guard secure else { registry.setSecure(site, false); return }

        isBusy = true; lastError = nil
        let provisioner = httpsProvisioner
        Task.detached(priority: .userInitiated) {
            var failure: String?
            do {
                try provisioner.enableHTTPS(for: site)
            } catch {
                failure = error.localizedDescription
            }
            await MainActor.run {
                self.isBusy = false
                if let failure { self.lastError = failure }
                else { self.registry.setSecure(site, true) } // → onRegistryChanged → reconcile
            }
        }
    }

    public func setNodePort(_ site: Site, _ port: Int?) {
        registry.setNodePort(site, port)
    }

    // Switch a site's engine with a zero-downtime handoff: bring the requested engine up on a
    // fresh backendPort, repoint the front to it, then reap the old backend. No Web Server restart.
    // Falls back to a plain persist when nothing is running (the next start applies it) or when the
    // request resolves to the engine already in use (apache requested but not installed → nginx).
    public func setSiteEngine(_ site: Site, _ engine: WebServerEngine) {
        guard site.type == .php else { return }
        let resolved = WebServerBackendFactory.effectiveEngine(engine, paths: paths)
        guard isRunning, !isBusy, let oldPort = site.backendPort, resolved != site.serverEngine else {
            registry.setServerEngine(site, engine)
            return
        }

        isBusy = true; lastError = nil
        let oldEngine = site.serverEngine
        let siteID = site.id
        let port = httpPort

        Task.detached(priority: .userInitiated) { [self] in
            do {
                let newPort = try await MainActor.run { try registry.nextFreeBackendPort() }
                await MainActor.run { registry.setEngineAndPort(siteID, engine: resolved, port: newPort) }
                let sites = await MainActor.run { registry.sites }
                // Site deleted mid-swap: release the busy lock (else isBusy sticks true and wedges
                // the whole server UI) and let the trailing reconcile settle config.
                guard let newSite = sites.first(where: { $0.id == siteID }) else {
                    await finish(missing: [], error: nil)
                    return
                }

                // Write the new backend conf + front vhost (now pointing at newPort) to disk, but do
                // not reload the front yet: the old backend on oldPort keeps serving until step 3.
                _ = try generator.generate(sites: sites, port: port)
                try await backends.startOne(site: newSite)   // new engine listening on newPort
                try nginx.reload()                           // front now routes the site to newPort
                // Let the front's pre-reload workers drain before reaping the old backend; they
                // still route to oldPort until they exit, so an immediate reap 502s those requests.
                try? await Task.sleep(nanoseconds: 1_500_000_000)
                backends.reap(siteID: siteID.uuidString, engine: oldEngine)
                await finish(missing: [], error: nil)
            } catch {
                // The old backend never stopped serving, so roll back to it and clean the half-started
                // new one; the trailing reconcile rewrites the front vhost back to oldPort.
                await MainActor.run { registry.setEngineAndPort(siteID, engine: oldEngine, port: oldPort) }
                backends.reap(siteID: siteID.uuidString, engine: resolved)
                await finish(missing: [], error: error.localizedDescription)
            }
        }
    }

    // Download the on-demand Apache engine; on success any apache-set site switches to it.
    public func installApache() {
        guard !apacheInstalling, !apacheInstalled else { return }
        apacheInstalling = true; apacheInstallError = nil
        let paths = paths
        Task.detached(priority: .userInitiated) {
            var failure: String?
            do {
                try await RuntimeDownloader(paths: paths).installArchive(
                    url: WebEngineCatalog.apacheURL,
                    sha256: WebEngineCatalog.apacheSHA256,
                    into: paths.apacheRoot,
                    markerRelPath: "bin/httpd",
                    onProgress: { _ in }
                )
            } catch { failure = error.localizedDescription }
            await MainActor.run {
                self.apacheInstalling = false
                if let failure { self.apacheInstallError = failure }
                else { self.apacheInstalled = true; self.reconcileAfterRuntimeChange() }
            }
        }
    }

    public func probeNode(_ site: Site) async -> NodeSiteController.State {
        await nodeSites.probe(site)
    }

    func onRegistryChanged() {
        onSitesChanged?(registry.sites)
        guard isRunning || phpRunning else { refreshWatches(); return }
        guard !isBusy else { pendingReconcile = true; return }
        reconcile()
    }

    public func reconcileAfterRuntimeChange() {
        onRegistryChanged()
    }

    func reconcile() {
        isBusy = true
        let sites = registry.sites
        let port = httpPort
        Task.detached(priority: .userInitiated) { [self] in
            do {
                let missing = try await applyConfiguration(sites: sites, port: port, startNginx: false)
                await finish(missing: missing, error: nil)
            } catch {
                await finish(missing: [], error: error.localizedDescription)
            }
        }
    }

    func handleFolderChange(_ folder: URL) {
        for site in registry.sites where site.path == folder.path {
            registry.reinspect(site)
        }
    }

    func refreshWatches() {
        watcher.watch(registry.sites.map { URL(fileURLWithPath: $0.path) })
    }

    func ensureSeed() {
        guard !didSeed, registry.sites.isEmpty else { didSeed = true; return }
        didSeed = true
        let demo = AppSupportPaths.defaultSitesRoot.appendingPathComponent("demo", isDirectory: true)
        try? Self.provisionSampleSite(at: demo.appendingPathComponent("public", isDirectory: true), domain: "demo.\(tld)")
        try? registry.add(folder: demo)
    }

    nonisolated static func provisionSampleSite(at docroot: URL, domain: String) throws {
        let fm = FileManager.default
        try fm.createDirectory(at: docroot, withIntermediateDirectories: true)
        let index = docroot.appendingPathComponent("index.php")
        guard !fm.fileExists(atPath: index.path) else { return }
        let body = """
        <?php
        // KTStack demo site — served at http://\(domain).
        echo "<h1>KTStack · \(domain) is live</h1>";
        phpinfo();
        """
        try body.write(to: index, atomically: true, encoding: .utf8)
    }
}
