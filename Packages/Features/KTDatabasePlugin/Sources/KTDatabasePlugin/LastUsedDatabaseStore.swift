import Foundation

public final class LastUsedDatabaseStore: @unchecked Sendable {
    private let defaults: UserDefaults
    private let keyPrefix = "ktstack.lastDatabase."
    private let lastProfileKey = "ktstack.lastProfileID"

    public var lastProfileID: UUID? {
        guard let str = defaults.string(forKey: lastProfileKey) else { return nil }
        return UUID(uuidString: str)
    }

    public func setLastProfileID(_ id: UUID?) {
        if let id {
            defaults.set(id.uuidString, forKey: lastProfileKey)
        } else {
            defaults.removeObject(forKey: lastProfileKey)
        }
    }
    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    public func lastDatabase(for profileID: UUID) -> String? {
        defaults.string(forKey: key(profileID))
    }

    public func setLastDatabase(_ database: String?, for profileID: UUID) {
        let storageKey = key(profileID)
        if let database, !database.isEmpty {
            defaults.set(database, forKey: storageKey)
        } else {
            defaults.removeObject(forKey: storageKey)
        }
    }

    private func key(_ profileID: UUID) -> String {
        keyPrefix + profileID.uuidString
    }
}
