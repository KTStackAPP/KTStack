import Foundation
import Combine


@MainActor
public final class AppPreferences: ObservableObject {
    public static let defaultTLD = "test"

   
    public static let safeTLDs = ["test", "localhost", "home.arpa", "internal"]

    
    public static var defaultSitesRootPath: String { AppSupportPaths.defaultSitesRoot.path }

    @Published public private(set) var sitesRootPath: String
    @Published public private(set) var tld: String

    private let defaults: UserDefaults
    private enum Key {
        static let sitesRoot = "KDWarm.sitesRootPath"
        static let tld = "KDWarm.tld"
    }

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.sitesRootPath = defaults.string(forKey: Key.sitesRoot) ?? Self.defaultSitesRootPath
        let stored = defaults.string(forKey: Key.tld) ?? Self.defaultTLD
       
        self.tld = Self.isValidTLD(stored) ? stored : Self.defaultTLD
    }

    public var sitesRootURL: URL { URL(fileURLWithPath: sitesRootPath) }

    // MARK: - Mutators (validate before persisting)

    
    public func setSitesRootPath(_ path: String) {
        let trimmed = path.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        sitesRootPath = trimmed
        defaults.set(trimmed, forKey: Key.sitesRoot)
    }

   
    @discardableResult
    public func setTLD(_ raw: String) -> Bool {

        let candidate = raw.trimmingCharacters(in: .whitespaces)
        guard candidate != tld else { return true }
        guard Self.isValidTLD(candidate) else { return false }
        tld = candidate
        defaults.set(candidate, forKey: Key.tld)
        return true
    }

    // MARK: - Validation


    public static func isValidTLD(_ s: String) -> Bool { DNSConstants.isValidTLD(s) }
}
