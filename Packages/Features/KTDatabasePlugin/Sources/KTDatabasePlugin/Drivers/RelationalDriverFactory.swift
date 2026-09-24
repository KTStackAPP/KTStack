import Foundation
import KTPlatformContracts
import KTStackCore

public typealias RelationalDriverFactory = @Sendable (ConnectionProfile, String?) -> RelationalDriver?

public enum RelationalDrivers {
    public static func factory(tools: any DatabaseToolsProviding) -> RelationalDriverFactory {
        { profile, password in
            switch profile.kind {
            case .mysql: MySQLDriver(profile: profile, password: password, tools: tools)
            case .postgres: PostgresDriver(profile: profile, password: password, tools: tools)
            case .sqlite: SQLiteDriver(profile: profile)
            case .mongodb: nil
            }
        }
    }

    public static let password: @Sendable (ConnectionProfile) -> String? = { profile in
        if profile.isManaged { return nil }
        return try? KeychainStore(service: DatabaseKeychain.service).get(account: profile.id.uuidString)
    }
}
