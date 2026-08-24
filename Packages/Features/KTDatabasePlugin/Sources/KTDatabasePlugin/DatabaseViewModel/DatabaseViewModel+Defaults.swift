import Foundation
import KTPlatformContracts
import KTStackCore

public extension DatabaseViewModel {
    static func defaultDriver(tools: any DatabaseToolsProviding) -> DriverFactory {
        { profile, password in
            switch profile.kind {
            case .mysql: MySQLDriver(profile: profile, password: password, tools: tools)
            case .postgres: PostgresDriver(profile: profile, password: password, tools: tools)
            case .sqlite: SQLiteDriver(profile: profile)
            case .mongodb: nil
            }
        }
    }

    static let defaultPassword: @Sendable (ConnectionProfile) -> String? = { profile in
        if profile.isManaged { return nil }
        return try? KeychainStore(service: DatabaseKeychain.service).get(account: profile.id.uuidString)
    }
}
