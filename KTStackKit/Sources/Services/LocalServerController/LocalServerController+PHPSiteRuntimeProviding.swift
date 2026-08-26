import Foundation
import KTPlatformContracts

extension LocalServerController: PHPSiteRuntimeProviding {
    public func sitesUsingPHP(version: String) -> [String] {
        registry.sites.filter { $0.type == .php && $0.phpVersion == version }.map(\.domain)
    }
}
