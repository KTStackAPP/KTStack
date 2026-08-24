import Foundation
import KTPlatformContracts
import KTStackCore

public extension DocumentViewModel {
    static func defaultDriver(tools: any DatabaseToolsProviding) -> DriverFactory {
        { profile, password in
            switch profile.kind {
            case .mongodb: MongoDriver(profile: profile, password: password, tools: tools)
            case .mysql, .postgres, .sqlite: nil
            }
        }
    }

    static let defaultPassword: @Sendable (ConnectionProfile) -> String? = { profile in
        if profile.isManaged { return nil }
        return try? KeychainStore(service: DatabaseKeychain.service).get(account: profile.id.uuidString)
    }
}
