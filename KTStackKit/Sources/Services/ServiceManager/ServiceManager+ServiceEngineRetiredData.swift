import Foundation
import KTPlatformContracts
import KTStackCore

extension ServiceManager {
    public func dataFootprint(_ engine: ServiceEngine, version: String) async -> ServiceEngineDataFootprint? {
        guard let found = await dataFootprint(kind: engine.serviceKind, version: version) else { return nil }
        return ServiceEngineDataFootprint(path: found.url.path, sizeBytes: found.bytes)
    }

    public func uninstall(_ engine: ServiceEngine, version: String) async throws -> String? {
        try await uninstall(kind: engine.serviceKind, version: version)?.path
    }

    public func retiredData(_ engine: ServiceEngine) async -> [ServiceEngineRetiredData] {
        await retiredData(kind: engine.serviceKind).map { entry in
            ServiceEngineRetiredData(
                engine: engine,
                version: entry.item.version,
                path: entry.item.url.path,
                removedAt: entry.item.removedAt,
                sizeBytes: entry.bytes
            )
        }
    }

    public func restoreRetiredData(_ item: ServiceEngineRetiredData) async throws {
        try await restoreRetiredData(platformItem(item), kind: item.engine.serviceKind)
    }

    public func trashRetiredData(_ item: ServiceEngineRetiredData) async throws {
        try await trashRetiredData(platformItem(item))
    }

    private func platformItem(_ item: ServiceEngineRetiredData) -> RetiredEngineData {
        RetiredEngineData(
            service: item.engine.serviceKind.rawValue,
            version: item.version,
            url: URL(fileURLWithPath: item.path, isDirectory: true),
            removedAt: item.removedAt
        )
    }
}
