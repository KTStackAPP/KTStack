import Foundation
import KTStackCore

extension ServiceManager {
    public func uninstall(kind: ServiceKind, version: String) async throws -> URL? {
        try validateUninstall(kind, version: version)
        let retired = try await Self.retireAndRemove(
            kind: kind, version: version, paths: paths, jobLoaded: jobLoadedProbe
        )
        objectWillChange.send()
        let remaining = catalog.installedVersions(kind)
        if let newActive = Self.repointedVersion(remaining: remaining, currentActive: activeVersion(kind)) {
            versionStore.setActiveVersion(kind, newActive)
        }
        return retired
    }

    public func dataFootprint(kind: ServiceKind, version: String) async -> (url: URL, bytes: Int64)? {
        await Self.footprint(EngineDataVault(paths: paths).liveData(service: kind.rawValue, version: version))
    }

    public func retiredData(kind: ServiceKind) async -> [(item: RetiredEngineData, bytes: Int64)] {
        await Self.listRetired(service: kind.rawValue, paths: paths)
    }

    public func restoreRetiredData(_ item: RetiredEngineData, kind: ServiceKind) async throws {
        if snapshot(kind)?.status == .running {
            throw ServiceVersionError(message: "Stop \(kind.displayName) before restoring data.")
        }
        try await Self.restore(item, label: kind.launchdLabel, displayName: kind.displayName, paths: paths, jobLoaded: jobLoadedProbe)
        objectWillChange.send()
    }

    public func trashRetiredData(_ item: RetiredEngineData) async throws {
        try await Self.trash(item, paths: paths)
        objectWillChange.send()
    }

    func validateUninstall(_ kind: ServiceKind, version: String) throws {
        if version == activeVersion(kind) {
            throw ServiceVersionError(message: "Set a different active version before uninstalling \(kind.displayName) \(version).")
        }
        if snapshot(kind)?.status == .running || busy.contains(kind) {
            throw ServiceVersionError(message: "Stop \(kind.displayName) before uninstalling a version.")
        }
    }

    nonisolated static func retireAndRemove(
        kind: ServiceKind,
        version: String,
        paths: AppSupportPaths,
        jobLoaded: @Sendable (String) -> Bool
    ) async throws -> URL? {
        if jobLoaded(kind.launchdLabel) {
            throw ServiceVersionError(
                message: "\(kind.displayName) is still loaded in launchd. Stop it before uninstalling a version."
            )
        }
        let retired = try EngineDataVault(paths: paths).retire(service: kind.rawValue, version: version)
        try FileManager.default.removeItem(at: paths.runtimeDir(kind.rawValue, version))
        return retired
    }

    nonisolated static func footprint(_ url: URL) async -> (url: URL, bytes: Int64)? {
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        return (url, EngineDataVault.size(of: url))
    }

    nonisolated static func listRetired(service: String, paths: AppSupportPaths) async -> [(item: RetiredEngineData, bytes: Int64)] {
        EngineDataVault(paths: paths).retired(service: service).map { ($0, EngineDataVault.size(of: $0.url)) }
    }

    nonisolated static func restore(
        _ item: RetiredEngineData,
        label: String,
        displayName: String,
        paths: AppSupportPaths,
        jobLoaded: @Sendable (String) -> Bool
    ) async throws {
        if jobLoaded(label) {
            throw ServiceVersionError(message: "\(displayName) is still loaded in launchd. Stop it before restoring data.")
        }
        try EngineDataVault(paths: paths).restore(item)
    }

    nonisolated static func trash(_ item: RetiredEngineData, paths: AppSupportPaths) async throws {
        try EngineDataVault(paths: paths).trash(item)
    }
}
