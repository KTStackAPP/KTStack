import Foundation
import KTPlatformContracts

extension EngineVersionsViewModel {
    func dataFootprint(_ engine: ServiceEngine, version: String) async -> ServiceEngineDataFootprint? {
        await engines.dataFootprint(engine, version: version)
    }

    func uninstall(_ engine: ServiceEngine, version: String) async -> Result<String?, Error> {
        do {
            let keptAt = try await engines.uninstall(engine, version: version)
            await reloadRetired(engine)
            return .success(keptAt)
        } catch {
            return .failure(error)
        }
    }

    func reloadRetired(_ engine: ServiceEngine) async {
        retired[engine] = await engines.retiredData(engine)
    }

    func retiredData(_ engine: ServiceEngine) -> [ServiceEngineRetiredData] {
        retired[engine] ?? []
    }

    func restoreBlockReason(_ item: ServiceEngineRetiredData) -> String? {
        guard let snap = snapshot(item.engine), snap.installed.contains(item.version) else {
            return "Install \(item.engine.displayName) \(item.version) to restore this data"
        }
        return switchBlockReason(item.engine)
    }

    func restore(_ item: ServiceEngineRetiredData) async -> Result<Void, Error> {
        do {
            try await engines.restoreRetiredData(item)
            await reloadRetired(item.engine)
            return .success(())
        } catch {
            return .failure(error)
        }
    }

    func trash(_ item: ServiceEngineRetiredData) async -> Result<Void, Error> {
        do {
            try await engines.trashRetiredData(item)
            await reloadRetired(item.engine)
            return .success(())
        } catch {
            return .failure(error)
        }
    }
}
