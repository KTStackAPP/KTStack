import Foundation

public extension DatabaseViewModel {

    static let defaultDriver: DriverFactory = { profile, password in
        switch profile.kind {
        case .mysql: return MySQLDriver(profile: profile, password: password)
        default:     return nil
        }
    }

   
    static let defaultPassword: @Sendable (ConnectionProfile) -> String? = { profile in
        if profile.isManaged { return nil }
        return try? KeychainStore().get(account: profile.id.uuidString)
    }
}
