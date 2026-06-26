import Foundation

public final class LastUsedDatabaseStore: @unchecked Sendable {
    private let defaults: UserDefaults
    private let keyPrefix = "ktstack.lastDatabase."

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
