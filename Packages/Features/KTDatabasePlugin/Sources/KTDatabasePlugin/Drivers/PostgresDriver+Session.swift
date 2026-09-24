import Foundation
import KTPlatformContracts

extension PostgresDriver {
    init(profile: ConnectionProfile, password: String?, tools: any DatabaseToolsProviding, session: ConnectionSession) {
        self.profile = profile
        self.password = password
        self.tools = tools
        self.session = session
    }
}
