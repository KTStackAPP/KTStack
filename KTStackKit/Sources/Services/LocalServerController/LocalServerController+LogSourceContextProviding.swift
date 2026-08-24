import Foundation
import KTPlatformContracts

extension LocalServerController: LogSourceContextProviding {
    public var siteDomains: [String] { registry.sites.map(\.domain) }
    public var phpVersions: [String] { availableVersions }
}
