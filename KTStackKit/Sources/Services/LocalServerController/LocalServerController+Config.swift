import Foundation
import KTStackCore

extension LocalServerController {
    public func validateNginxConfig() async -> NginxValidationResult {
        let nginx = self.nginx
        let paths = self.paths
        return await Task.detached(priority: .userInitiated) {
            guard FileManager.default.isExecutableFile(atPath: paths.nginxBinary.path) else {
                return .couldNotRun
            }
            do {
                try nginx.test()
                return .valid
            } catch let NginxController.ControlError.commandFailed(_, _, out) {
                return .invalid(out.isEmpty ? "nginx -t failed" : out)
            } catch {
                return .couldNotRun
            }
        }.value
    }

    public func reloadNginxConfig() async throws {
        let nginx = self.nginx
        try await Task.detached(priority: .userInitiated) {
            try nginx.reload()
        }.value
    }

    public func reloadPHPPool(version: String) async throws {
        let pools = pools
        try await Task.detached(priority: .userInitiated) {
            try pools.reload(version: version)
        }.value
    }

    public func restartPHPPool(version: String) async throws {
        let pools = pools
        try await Task.detached(priority: .userInitiated) {
            try pools.restart(version: version)
        }.value
    }

    // A fresh install ships no PHP runtime (it is an on-demand download, never bundled), so a PHP
    // site 502s with no obvious cause. Best-effort: fetch the default version before the first serve
    // when a PHP site actually needs it. A failure must NOT abort start(), or an offline or
    // node/static-only user would get no server at all; php-fpm's `missing` path then surfaces the
    // "Install PHP from Runtimes" banner and static/node sites keep working.
    nonisolated func ensureDefaultPHPInstalled(sites: [Site]) async {
        guard sites.contains(where: { $0.type == .php }),
              BundledPHP.availableVersions(php: paths.phpRuntimesRoot).isEmpty
        else { return }
        let version = BundledPHP.defaultVersion
        guard let release = RuntimeCatalog.manifest.first(where: { $0.language == .php && $0.version == version }),
              release.supportsCurrentArch
        else { return }
        await MainActor.run { self.bootstrapStatus = "Downloading PHP \(version)…" }
        defer { Task { @MainActor in self.bootstrapStatus = nil } }
        do {
            try await RuntimeDownloader(paths: paths).installArchive(
                url: release.url,
                sha256: release.sha256,
                into: paths.runtimeDir(RuntimeLanguage.php.rawValue, version),
                markerRelPath: RuntimeLanguage.php.executableRelPath,
                onProgress: { p in
                    let pct = Int(p.fraction * 100)
                    Task { @MainActor in self.bootstrapStatus = "Downloading PHP \(version)… \(pct)%" }
                }
            )
        } catch {
            NSLog("KTStack: default PHP \(version) download failed, PHP sites will 502 until installed: \(error.localizedDescription)")
        }
    }

    nonisolated func applyConfiguration(
        sites: [Site],
        port: Int,
        startNginx: Bool,
        runPreflight: Bool = true
    ) async throws -> [String] {
        let changed = try generator.generate(sites: sites, port: port)

        let phpUp = !pools.activeVersions.isEmpty && pools.activeVersions.allSatisfy { pools.isRunning(version: $0) }
        if startNginx || phpUp {
            _ = try pools.reconcile(required: generator.poolVersions(for: sites))
            for version in pools.activeVersions {
                try await Self.waitForSocket(pools.socket(for: version))
            }
        }
        // Per-site backends must be listening before the front routes to them, else the front
        // reloads into a dead loopback port and 502s the host. Per-site failures are isolated.
        await backends.reconcile(sites: sites)
        let installedPHP = Set(BundledPHP.availableVersions(php: paths.phpRuntimesRoot))
        let missing = SiteConfigGenerator.requiredVersions(for: sites)
            .subtracting(installedPHP).sorted()
        if startNginx {
            if runPreflight {
                switch preflight.firstConflict(in: frontPorts(for: sites, httpPort: port)) {
                case .available: break
                case let .inUse(_, m), let .blocked(m): throw NSError(
                        domain: "KTStack",
                        code: 2,
                        userInfo: [NSLocalizedDescriptionKey: m]
                    )
                }
            }
            try nginx.start()
            try await Self.waitForListening(frontPorts(for: sites, httpPort: port))
        } else if changed {
            do { try nginx.reload() }
            catch { NSLog("KTStack: nginx reload failed: \(error.localizedDescription)") }
        }
        return missing
    }

    // Front owns :80 always and :443 only when a secure site's cert exists (same predicate the
    // config writer uses to emit the :443 listener), so preflight matches what nginx will bind.
    nonisolated func frontPorts(for sites: [Site], httpPort: Int) -> [Int] {
        generator.frontBindsTLS(for: sites) ? [httpPort, 443] : [httpPort]
    }

    // `launchctl bootstrap` returning 0 only means the job registered, not that nginx bound its ports.
    // Under KeepAlive a bind failure (port conflict, crash-loop) would otherwise read as "running" with
    // nothing on :443. Probe each front port so the failure surfaces as an error instead.
    nonisolated static func waitForListening(_ ports: [Int], timeout: TimeInterval = 4) async throws {
        let checker = HealthChecker()
        for port in ports {
            let deadline = Date().addingTimeInterval(timeout)
            while await checker.check(.tcp(port: port)) != .running {
                if Date() >= deadline {
                    throw NSError(
                        domain: "KTStack",
                        code: 3,
                        userInfo: [NSLocalizedDescriptionKey:
                            "nginx started but nothing is listening on port \(port). It likely failed to bind "
                                + "(port already in use) and launchd is restarting it. See the nginx error log."]
                    )
                }
                try await Task.sleep(nanoseconds: 100_000_000)
            }
        }
    }

    nonisolated static func waitForSocket(_ url: URL, timeout: TimeInterval = 5) async throws {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if FileManager.default.fileExists(atPath: url.path) { return }
            try await Task.sleep(nanoseconds: 50_000_000)
        }
        throw NSError(
            domain: "KTStack",
            code: 1,
            userInfo: [NSLocalizedDescriptionKey: "php-fpm socket did not appear in time."]
        )
    }
}
