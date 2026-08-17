import Foundation

extension ServiceManager {
    public func install(_ kind: ServiceKind) {
        guard activeInstallKey(kind) == nil else { return }
        guard let release = catalog.availableRelease(kind) else {
            if !catalog.isInstalled(kind),
               ServiceBinaryCatalog.manifest.contains(where: { $0.kind == kind })
            {
                installError[kind.rawValue] = "\(kind.displayName) isn't available for \(ServiceBinaryCatalog.arch) yet."
            }
            return
        }
        let key = release.id
        let marker = ServiceBinaryCatalog.marker(kind) ?? ""
        let dest = catalog.installDir(release)
        downloadFraction[key] = 0
        installError[key] = nil
        installError[kind.rawValue] = nil
        let downloader = downloader
        installTasks[key] = Task { [weak self] in
            do {
                try await downloader.installArchive(
                    url: release.url, sha256: release.sha256, into: dest, markerRelPath: marker
                ) { progress in
                    Task { @MainActor [weak self] in
                        guard self?.downloadFraction[key] != nil else { return }
                        self?.downloadFraction[key] = progress.fraction
                    }
                }
                await self?.finishInstall(key, error: nil)
            } catch is CancellationError {
                await self?.finishInstall(key, error: nil)
            } catch {
                await self?.finishInstall(key, error: error.localizedDescription)
            }
        }
    }

    public func cancelInstall(_ kind: ServiceKind) {
        let prefix = "\(kind.rawValue)-"
        for key in Array(installTasks.keys) where key.hasPrefix(prefix) {
            installTasks[key]?.cancel()
            installTasks[key] = nil
            downloadFraction[key] = nil
        }
    }

    public func install(_ release: ServiceBinaryRelease) {
        let key = release.id
        guard installTasks[key] == nil, activeInstallKey(release.kind) == nil else { return }
        let marker = ServiceBinaryCatalog.marker(release.kind) ?? ""
        let dest = catalog.installDir(release)
        downloadFraction[key] = 0
        installError[key] = nil
        installError[release.kind.rawValue] = nil
        let downloader = downloader
        installTasks[key] = Task { [weak self] in
            do {
                try await downloader.installArchive(
                    url: release.url, sha256: release.sha256, into: dest, markerRelPath: marker
                ) { progress in
                    Task { @MainActor [weak self] in
                        guard self?.downloadFraction[key] != nil else { return }
                        self?.downloadFraction[key] = progress.fraction
                        self?.objectWillChange.send()
                    }
                }
                await self?.finishInstall(key, error: nil)
            } catch is CancellationError {
                await self?.finishInstall(key, error: nil)
            } catch {
                await self?.finishInstall(key, error: error.localizedDescription)
            }
        }
    }

    public func cancelInstall(_ release: ServiceBinaryRelease) {
        let key = release.id
        installTasks[key]?.cancel()
        installTasks[key] = nil
        downloadFraction[key] = nil
        objectWillChange.send()
    }

    func finishInstall(_ key: String, error: String?) {
        installTasks[key] = nil
        downloadFraction[key] = nil
        if let error { installError[key] = error }
    }

    public func installedVersions(_ kind: ServiceKind) -> [String] {
        catalog.installedVersions(kind)
    }

    public func availableReleases(_ kind: ServiceKind) -> [ServiceBinaryRelease] {
        catalog.availableReleases(kind)
    }

    public func activeVersion(_ kind: ServiceKind) -> String? {
        versionStore.activeVersion(kind)
    }

    public func setActiveVersion(_ kind: ServiceKind, version: String) throws {
        guard snapshot(kind)?.status != .running else {
            throw ServiceVersionError(message: "Stop \(kind.displayName) before switching versions.")
        }
        objectWillChange.send()
        versionStore.setActiveVersion(kind, version)
    }

    public func uninstall(kind: ServiceKind, version: String) throws {
        if version == activeVersion(kind) {
            throw ServiceVersionError(message: "Set a different active version before uninstalling \(kind.displayName) \(version).")
        }
        if snapshot(kind)?.status == .running {
            throw ServiceVersionError(message: "Stop \(kind.displayName) before uninstalling a version.")
        }
        objectWillChange.send()
        let fm = FileManager.default
        try fm.removeItem(at: paths.runtimeDir(kind.rawValue, version))
        try? fm.removeItem(at: paths.serviceData(kind.rawValue, version: version))
        let remaining = catalog.installedVersions(kind)
        if let newActive = Self.repointedVersion(remaining: remaining, currentActive: activeVersion(kind)) {
            versionStore.setActiveVersion(kind, newActive)
        }
    }

    nonisolated static func repointedVersion(remaining: [String], currentActive: String?) -> String? {
        guard let currentActive, !remaining.contains(currentActive) else { return nil }
        return remaining.max { $0.compare($1, options: .numeric) == .orderedAscending }
    }

    public func installProgress(for release: ServiceBinaryRelease) -> Double? {
        downloadFraction[release.id]
    }

    public func isInstallInFlight(_ kind: ServiceKind) -> Bool {
        activeInstallKey(kind) != nil
    }

    func activeInstallKey(_ kind: ServiceKind) -> String? {
        let prefix = "\(kind.rawValue)-"
        return downloadFraction.keys.first { $0.hasPrefix(prefix) }
    }

    func installErrorMessage(_ kind: ServiceKind) -> String? {
        let prefix = "\(kind.rawValue)-"
        for (key, msg) in installError {
            if key.hasPrefix(prefix) || key == kind.rawValue { return msg }
        }
        return nil
    }
}
